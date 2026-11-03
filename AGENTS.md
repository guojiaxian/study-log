# AGENTS.md · StudyLog 项目记忆（供 AI Agent 读取）

> **读者**：在本仓库工作的 AI Agent。人类请读 [README.md](README.md)、[docs/01-产品设计手册.md](docs/01-产品设计手册.md)、[docs/02-开发手册.md](docs/02-开发手册.md)。
> **维护纪律**：任何 Agent 修改了业务口径、目录结构或验证方式后，必须同步更新本文件对应小节。
> **最后更新**：2026-11-03（运维形态改为强制 systemd 托管 + scripts/ 手动控制入口）。

---

## 0. 5 分钟上手（新 Agent 的第一件事）

```bash
# 1) 服务是否活着（期望 status:"ok"、version:"1.2.0"）
curl -s http://127.0.0.1:3000/api/v1/health
bash deploy/status.sh                    # 单元状态 + 开机自启 + 健康检查

# 2) 改代码前先跑基线测试
npm test                                 # Web：14 项（server/test/lib.test.js）
node /root/applications/study-log-wxmp/tools/test.js    # 小程序：98 项（若涉及）

# 3) 改完必须重建再重启（前端改动不 --build 不会生效）
scripts/restart.sh --build
```

**最容易犯的三个错**

1. **把 730 写死** —— 满分必须 `gradeFullScore(grade)` 推导（初三 730 / 初二 570），见第 4 节。
2. **在页面里自建统计口径** —— 派生指标只许在 `server/src/lib/metrics.js`（及小程序同名文件）实现。
3. **改了前端只重启不构建** —— Fastify 托管的是 `web/dist`，不 `--build` 看不到变化。

**读代码顺序**：`server/src/server.js` → `app.js` → `routes/*.js` → `services/*.js` → `lib/metrics.js`；前端从 `web/src/views/` 逐页对照 docs/01 第 6 章原型走。

**改动前必读**：第 4 节（业务口径，改统计/展示前）、第 8 节（红线）。

## 1. 仓库是什么（一句话）

面向单个家庭自用的初中生成绩记录系统（郑州，2027 年中考），包含**两个独立交付物**：

| 交付物 | 位置 | 形态 | 状态 |
| --- | --- | --- | --- |
| **StudyLog Web 版**（原始项目） | `server/` + `web/` | Node 22 + Fastify 4 + SQLite（`node:sqlite`）后端；Vue 3 + Vite 前端（构建产物由 Fastify 托管） | 已上线运行（端口 3000，真实成绩已灌入） |
| **微信小程序版** | `/root/applications/study-log-wxmp`（**2026-11-02 起移出本仓库**，与本仓库平级） | 原生小程序（WXML/WXSS/JS + CommonJS），**无后端、无 npm 依赖、无构建步骤**；数据存小程序本机 storage（键前缀 `wxmp_`） | 2026-10-31 完成，2026-11-01 补齐功能差距，业务层 98 项测试通过 |

两者**功能同构、统计口径一致，但数据完全隔离**：小程序不依赖 Web 版的任何接口/端口/数据库文件；Web 版已有的 SQLite 数据不会出现在小程序里，反之亦然。

- 产品名：「孙晗菲的学习记录」（界面标题）；单用户、**无登录鉴权**，打开即用。
- 核心场景：录入周测/月考/期中期末成绩 → 趋势与进退对比 → AI 学情分析 → 目标高中（郑外/郑州一中/省实验）差距对比。

## 2. 关键路径速查

```
server/src/app.js             Fastify 装配（路由、错误处理、静态托管）
server/src/server.js          入口：监听 3000、迁移自动执行、AI 自检
server/src/db/migrations/     001_init / 002_view / 003_school_line_mode / 004_subject_by_grade（DDL 冻结基线）
server/src/lib/metrics.js     ★ 派生指标口径唯一实现（round2/mean/stddev/declineRun/totalOfScores/rankDelta）
server/src/lib/schoolCompare.js  录取线折算/取值/差距（toBase730/pickLineScore/gapOf/latestPerSubjectTotal）
server/src/lib/subjectMatch.js   科目名匹配（exact→alias→fuzzy→unmatched）
server/src/lib/ruleAnalysis.js   规则兜底报告
server/src/services/*.js      subject(按学段)/exam/stats/school/ai/analysis/config/examType/data
web/src/views/*.vue           Dashboard/Trend/ExamList/ExamDetail/Analysis/Targets/Manage/EntryManual/EntryAi
scripts/*.sh                  日常手动控制：start(enable+start)/restart(--build)/stop(stop+disable=永久关闭)
deploy/*.sh                   install-service(渲染单元)/status/log/deploy(发版)；start/stop/restart 为转发壳
docs/01-产品设计手册.md        产品口径与原型（第 2.2 科目分值表、6.4 派生指标定义是准绳）
docs/02-开发手册.md            DDL、接口报文、AI 契约（第 4/5/6 章为冻结基线）

/root/applications/study-log-wxmp/   （已移出本仓库，勿在本仓库 git 内操作它）
├── app.json                  12 个页面注册 + tabBar（首页/趋势/总览/目标/分析）
├── utils/                    业务层（由 server/src 移植：db/metrics/subject*/exam*/stats*/school*/ai*/analysis*/data*/config*/format）
│   ├── db.js                 本地存储数据层 + 种子字典；resetAll()；无事务（靠先全量校验后写入保证原子性）
│   ├── ruleParser.js         离线规则解析器（小程序新增，AI 未配置时批量录入的兜底）
│   └── aiService.js          OpenAI 兼容调用（wx.request）+ extractJson/repairJson + 配置存 wxmp_ai
├── components/line-chart/    自研 Canvas 2D 折线图（多系列/null 断点/反向 Y/参考线/触摸提示）
├── pages/                    12 页：dashboard/trend/exams/targets/analysis(tab) + manage/entry-manual/entry-ai/exam-detail/subject-config/school-config/ai-settings
├── tools/test.js             ★ 测试 harness（mock wx.* 存储，纯 Node 跑业务层，98 项断言）
├── tools/gen-icons.js        tabBar PNG 图标生成器（81×81，纯 Node 手写 PNG）
└── docs/移植说明.md           使用注意事项（数据备份、AI 密钥在本机、域名白名单等）
```

## 3. 如何运行与验证

```bash
# ---- Web 版 ----
curl -s http://127.0.0.1:3000/api/v1/health     # 健康检查：{status:"ok", dbReady:true, version:"1.2.0"}
bash deploy/status.sh                           # 单元状态 + 开机自启状态 + 健康检查
systemctl is-enabled studylog                   # 应为 enabled（scripts/stop.sh 后变 disabled）
npm test                                        # Vitest 单元测试（server/test/lib.test.js）

# ---- 小程序版（目录已移出本仓库，用绝对路径）----
node /root/applications/study-log-wxmp/tools/test.js    # 业务层口径测试（mock wx，当前 98 项全过）
# 界面验证：微信开发者工具导入 /root/applications/study-log-wxmp/（appid 为 touristappid 测试号）
node /root/applications/study-log-wxmp/tools/gen-icons.js    # 重新生成 assets/tab/*.png

# ---- 静态检查（小程序无编译器，改完至少做这两步）----
find /root/applications/study-log-wxmp -name "*.js" | xargs -I{} node --check {}     # 语法
# JSON 可解析 + app.json 每个页面四件套（js/json/wxml/wxss）齐全
```

**改 Web 前端后必须 `scripts/restart.sh --build`（先构建再重启）；只改服务端 `scripts/restart.sh` 即可。**
服务由 systemd 托管：开机自启 + `Restart=always` 崩溃自愈；**不要再用 nohup 手动起进程**（见第 9 节）。
小程序改完无需构建，开发者工具重新编译即可。

## 4. 业务口径（改任何统计/展示代码前必读）

| 口径 | 规则 |
| --- | --- |
| 学段 | `grade` 只取 **8（初二）/ 9（初三）**。两学段科目集合与满分不同：初二计入总分满分 **570**（历史 70；生物/地理为等级制不计分）；初三 **730** 中考口径（历史 50、化学 50、体育 100、理化生实验 30；**无生物/地理**）。满分一律由 `subject_grade` 字典求和推导（`gradeFullScore(grade)`），**禁止硬编码 730** |
| 总分 | `Σ(该学段计入总分 && 未缺考 && score!=null)`；**卷面满分 `enteredFullScore`** = 本次已录且计入总分科目的满分之和（如初三 10 月月考只考 7 科 = 600），与学段满分（730）是两个概念，页面必须同时标注 |
| 满分校验 | `0 ≤ score ≤ 该学段该科 fullScore`（应用层校验）；等级科目（scoreMode='grade'）只收 A/B/C/D、禁止填分数；缺考不计入任何统计 |
| 趋势 | 已确认考试（status='confirmed'）升序；**sport/lab 单项测试默认排除**（`SPECIAL_EXAM_TYPES`）；缺考/未录渲染为**断点（null），不得按 0 处理**；总分参考线取所展示考试 `enteredFullScore` 的最大值（600 而非 730，避免"缺 130 分"误读） |
| 跨学段 | 总分趋势按学段分开看；`grade='comparable'` 单科混连**仅限两学段满分相同的科目**（语/数/英/物/道法 5 科；历史 70/50 不参与），且不提供总分系列 |
| 历史均值 | 滑窗默认近 **8** 次（`stats.avgWindow`）；连续下滑 = 末尾**严格**递减 ≥ **3** 次（`stats.declineThreshold`）；两者可配 |
| 排名 | 数值越小越好；名次进退 = 上次 − 本次（正=进步）；文案用「进步/退步 N 名」；排名趋势图 **Y 轴必须反向**；排名字段可空，人数取请求值或全局配置 `rank.classSize/gradeSize` |
| 目标差距 | **`gap = 录取线 − 我的中考口径总分`；正值 = 还需提分，负值/0 = 已超线**（docs/01、docs/02、JSDoc、接口 notes、目标页图例已于 2026-11-02 全部对齐）；我的总分 = 初三各计入总分科目「最近一次已录入得分」之和；录取线跨口径（totalFullScore≠730）先折算；逐校采用线 `line_mode`：`avg3y`/`latest`（**默认 latest**）/`custom` |
| AI 铁律 | AI 不直接写库（解析结果必须经用户校对后 `commit`，服务端复核全部约束）；AI 不产生数字（学情分析只许引用摘要数值）；AI 不可用必须降级（规则解析/规则报告）而不阻断主流程 |
| 指标唯一实现 | 派生指标只许在 `server/src/lib/metrics.js`（Web）与 `/root/applications/study-log-wxmp/utils/metrics.js`（小程序）实现，页面/前端不得自建第二套口径 |

内置种子（Web 由迁移 001/003/004 写入；小程序由 `db.js ensureInit()` 写入）：11 科目身份、9 考试类型、3 校近三年统招线（郑外 707/699/699，一中 702/694/697，省实验 702/694/695，均为 730 口径）、科目别名表（`subject_alias`：道法→道德与法治等）。**考试成绩不在种子里**（Web 真实成绩由 `npm run seed:real` 灌入；小程序刻意从零开始）。

## 5. 工程约定

- 命名：DB 字段 `snake_case`、JS 变量 `camelCase`、接口路径 `kebab-case` 复数资源；日期一律 `YYYY-MM-DD`（`Asia/Shanghai`）。
- 接口：前缀 `/api/v1`，统一 `{code, message, data}`；错误码 `0/1001(校验)/2001(不存在)/2002(冲突)/2003(约束)/3001(AI不可用)/3002(AI输出不可解析)/3003(AI额度鉴权)/5000`。小程序 `utils/errors.js` 同构复用。
- 路由层只做校验+调服务层；服务层不做 HTTP 逻辑；多次写入必须包事务（Web 用 `db.transaction()`；小程序无事务，用「先全量校验后写入」替代）。
- 迁移：顺序 SQL + `schema_version` 表，**每个迁移文件末尾必须自带 `INSERT OR IGNORE INTO schema_version`**（003 曾漏写导致启动重放报 duplicate column）；启动时自动执行，失败拒绝启动。
- 小程序 storage 表：`wxmp_subject / wxmp_subject_grade / wxmp_exam / wxmp_score / wxmp_exam_type / wxmp_school / wxmp_school_line / wxmp_report / wxmp_parse_task / wxmp_config(对象) / wxmp_ai(对象) / wxmp_meta(对象)`；备份导出 JSON 带 `version: "studylog-wxmp/1"`，导入为覆盖式（保留 AI 设置）；`wxmp_parse_task` 上限 200 条。

## 6. AI 集成要点

- 协议：OpenAI 兼容 `POST {AI_BASE_URL}/chat/completions`，默认 DeepSeek；`response_format: json_object`；解析 temperature=0 / 分析 0.3；max_tokens 解析 4000 / 分析 12000。
- **推理型模型（deepseek-flash/R1）先消耗大量 reasoning token**：预算不足会导致 JSON 截断甚至 content 为空 → 报 3001 并提示调大预算；`extractJson` 内置截断修复（`repairJson`：补引号、按栈闭合、去尾逗号）。
- Web 版密钥仅在服务端 `.env`（`AI_API_KEY`），**绝不下发前端、不要在输出中打印**；小程序版密钥存本机 `wxmp_ai`（无服务端可存），导出备份不含密钥。
- 学情分析输入是 `buildSummary()` 的**中文化键**摘要（`toChineseSummary`），提示词强制正文全中文、禁英文字段名回显；输出 JSON 键：`overall/strengths/weaknesses/trend/rankTrend/targetGap/suggestions`，拼成 Markdown 落 `analysis_report` 表。
- 小程序未配置 Key 时：批量录入自动降级 `ruleParser.ruleParse`（正则识别「别名+分数/等级」、考试类型关键词、`班级排名 8/50` 式排名），输出结构与 AI 解析完全一致、仍强制校对。

## 7. 环境事实（两台机器，勿混淆）

| | 开发机（本仓库：**`/root/applications/study-log`**，AI 会话环境） | 生产机（阿里云 ECS，带公网 IP） |
| --- | --- | --- |
| 配置 | 32 核 Hygon / 30GB 内存 / 957G 盘，Linux ky10 | **2 核 / 2GB / 40GB**（资源紧张，容量预算以此为准） |
| Node | v22.19.0 系统级安装（勿用 nvm；`node:sqlite` 要求 ≥22.5） | 系统级 Node 22.x（systemd 单元写死 `/usr/bin/node`，禁止升级/降级/覆盖） |
| studylog 运行形态 | **systemd 单元 `studylog.service`**（2026-11-03 起）：`/root/applications/study-log`，node `/usr/local/bin/node`，开机自启 + `Restart=always`；启停走 `scripts/start.sh` / `stop.sh`（**stop = 永久关闭**：stop+disable） | 同一套单元（模板由 `deploy/install-service.sh` 按路径渲染）：`/root/studylog`，node `/usr/bin/node`，端口 3000，`MemoryMax=450M` |
| 其它 | 机器上还有 nginx(80)、docker、adb(5037) 等无关服务，同样不许动 | 默认无 Nginx、无数据库进程；对外端口靠阿里云安全组 |

- 开发机 `data/studylog.db`（WAL）+ `*.bak.NNN` + PID 文件：**生产数据，禁止删除/移动**；从备份恢复必须同时删 `-wal/-shm`。
- `.env` 含 `AI_API_KEY`：可读但**不得把值打印/外传**。
- git：分支 `main`，远端 `git@github.com:guojiaxian/study-log.git`（**2026-11-03 由 `Study-log` 改名，旧地址仍可重定向但会打印 moved 警告，生产机建议 `git remote set-url` 更新**），用户 guojiaxian。历史上约 28 项用户未提交改动已于 **2026-11-02 随 v1.2.0 提交入库**；此后保持工作区干净，勿再积压未提交改动。
- 小程序已于 2026-11-02 由用户移出本仓库（现位于 `/root/applications/study-log-wxmp`），**用户明确要求小程序不上传 git**——本仓库内不应再出现 `study-log-wxmp/` 目录；若未来移回，仍不得 `git add` 或推送。
- **同机部署第二个 Web 服务的环境要求**见根目录 [`新服务环境准备要求.md`](新服务环境准备要求.md)（2026-11-01 交付外部开发者的硬约束文档：2GB 内存预算、禁常驻 DB、端口 3100–3299 段、隔离与回归清单）。

### 7.1 生产机（`/root/studylog`）部署要点

```bash
cd /root/studylog
git remote set-url origin git@github.com:guojiaxian/study-log.git   # 仓库已改名，建议更新
systemctl stop studylog && cp data/studylog.db data/studylog.db.bak.$(date +%Y%m%d)
bash deploy/deploy.sh                                               # 拉码→装依赖→构建→重启→健康检查
curl -s localhost:3000/api/v1/health                                # 期望 version:"1.2.0"
```

- **拉代码不会改 systemd 单元**：`/etc/systemd/system/studylog.service` 在仓库外，`git pull` 不动它。生产已有的旧单元（`WorkingDirectory=/root/studylog`、`ExecStart=/usr/bin/node`、`EnvironmentFile=.env`、日志 `logs/stdout.log`）继续正常工作。
- **只有显式执行 `deploy/install-service.sh` 才会刷新单元**，届时变化：日志 `logs/stdout.log` → `logs/app.log`；去掉 `EnvironmentFile`（改由 `loadEnv()` 读 cwd 下的 `.env`）；`ExecStart` 的 node 换成 `command -v node` 的结果。**执行前先确认生产 `command -v node` 就是 `/usr/bin/node`**（生产禁止升级/覆盖系统 node）。
- `scripts/start.sh` 在单元已存在时**不会**改写它，只做 `enable` + `start` —— 生产沿用旧单元属预期行为。
- `deploy/deploy.sh` 含 `git clean -fd`：会删除生产目录的未跟踪文件。`.env` / `data/` / `logs/` 均已 gitignore（安全），但不要在 `/root/studylog` 放手工脚本。
- 迁移：`schema_version` 已登记则跳过。若生产仍 < 4，首次启动会跑 `004_subject_by_grade.sql`（纯增量：建表 + `INSERT OR IGNORE` + 重建视图，不动考试数据），`migrate.js` 会自动留 `.bak.004` 快照。
- **绝不**在生产跑 `npm run seed:real` / `seed:demo`（会 `DELETE` 考试与成绩）。

## 8. Agent 行为红线（历次会话确立的约束）

1. 在 `/root/applications/study-log-wxmp`（小程序，已移出本仓库）上工作时：**只读**对待 Web 版——不改、不删、不停服务、不占端口、不产生数据/环境冲突。
2. 不得修改 `server/src/db/migrations/` 已发布文件（只许新增迁移）。
3. 小程序数据隔离是**特性不是缺陷**：不要给小程序"接上"Web 版接口或共享 SQLite 来"打通数据"，除非用户明确要求。
4. 改小程序业务层后：跑 `node /root/applications/study-log-wxmp/tools/test.js` 必须全绿；改口径必须同步双端（metrics.js ×2）并在本文件第 4 节登记。
5. 向 `.env`、systemd、nginx 等系统级配置写入需先征得用户同意。

## 9. 已知坑与修复记录（避免重蹈）

| 坑 | 事实/修复 |
| --- | --- |
| 小程序 `examId` 别名丢失 | 本地无 SQL 别名，`shapeExam` 曾漏 `examId` 字段导致趋势/对比全空；已补 `examId: exam.id`。新增"等价于视图/SQL 别名"的映射时逐字段核对 |
| 无事务写入的原子性 | 小程序 storage 无事务；`createExam/updateExam` 曾"先写考试再校验成绩"，校验失败留下孤儿考试。已改为 **先 `validateScores()` 全量校验、后落库**，新增写路径必须沿用该模式 |
| 图标绘制发虚 | 手写 PNG 光栅化时 `rect` 覆盖度误除 SS²、`seg` 只写每像素单子采样；已修（rect 用实际相交面积、seg 用圆头距离测试）。回归：`tools/gen-icons.js` 后用 alpha 通道 ASCII 渲染自查 |
| WXML 没有 `<table>` | 小程序 WXML 不支持 HTML 表格标签，表格用 flex view 行实现（见 dashboard/exam-detail 的 `.grid-row`） |
| 迁移漏登记版本号 | 003 曾漏 `schema_version` 导致每次启动重放报 duplicate column；见第 5 节约定 |
| 推理模型 token 截断 | 见第 6 节；用户侧表现为"AI 未返回有效内容/输出被截断"，解法是调大 `AI_MAX_TOKENS_*`（小程序在 AI 设置页调） |
| WAL 恢复不彻底 | 只 cp `.db` 不删 `-wal/-shm` 会回放旧写入，"恢复无效"；见第 7 节 |
| **nohup 起的服务会被上层会话清理杀掉** | 2026-11-03 08:59：ZCode 服务端自我更新重启（`journald: server-supervisor stopped` 08:59:28.491），10ms 后 StudyLog 收到 SIGTERM 优雅退出（`logs/app.log` 末行「收到 SIGTERM」）。原因：nohup 起的进程仍属启动它的会话进程树，**nohup 只挡 SIGHUP 不挡 SIGTERM**，且无 systemd 单元 → 无人拉起。**根治：全部走 systemd 托管**（`Restart=always` 已用 `kill -9` 实测可自愈），不要再用 nohup 起服务 |
| **systemd 单元是仓库外的产物** | `/etc/systemd/system/studylog.service` 不由 `git pull` 更新，也不由 `scripts/start.sh` 重写。仓库里只有模板 `deploy/studylog.service`（`@ROOT@`/`@NODE@` 占位符），刷新必须显式跑 `deploy/install-service.sh`。改模板后忘了刷新 = 线上行为不变（不是 bug，是设计） |
| systemd 243 读不到日志路径 | `systemctl show -p StandardOutput --value` 只返回 `append`，拿不到路径。`deploy/log.sh` 改为 `systemctl cat` 后用 `sed 's/^StandardOutput=append://p'` 解析，新旧单元模板都能正确取到（新 → `logs/app.log`，旧 → `logs/stdout.log`） |
| `stray_pids` 误判正常进程 | 按「命令行含入口 + cwd=项目根」扫描会把 systemd 正常托管的 MainPID 也当成残留；已用 `systemctl show -p MainPID --value` 排除，否则 `scripts/start.sh` 会误报端口冲突 |
| `findExamsForStats` 忽略 includeDraft | 参数存在于签名但实现硬编码只取 confirmed；矩阵状态筛选暴露后已修。新增带状态语义的统计查询时先验证该参数 |
| 文档与实现的两处偏差 | ① gap 正负号、② 采用线默认 latest——曾长期文档写反/不一致，**2026-11-02 已全面对齐**（docs/01 FR-7.2/C-11、docs/02 5.3 示例与 6.5、`gapOf` JSDoc、`/schools/compare` notes、目标页图例统一为「正值=还需提分」「默认 latest」）。若再改口径需双端同步并更新本文件 |

## 10. 工作日志（provenance）

- **2026-10-31**：通读 Web 版（README、docs/01/02、DDL、全部 services/lib）；在 `study-log-wxmp/` 从零产出原生微信小程序——utils 业务层 16 个模块、line-chart 组件、12 个页面、tabBar 图标生成器、83 项断言的测试 harness（全部通过）、README 与 docs/移植说明.md。全程未改动 Web 版任何文件、未触碰 3000 端口服务、未执行 git 写操作。过程中修复 examId 映射缺失与无事务孤儿考试两个缺陷（见第 9 节）。
- **2026-11-01**：补齐小程序与 Web 版的功能差距（98 项断言全过）：趋势页/总览页日期范围筛选、关键词搜索、状态（草稿/确认）筛选与草稿标签、总览按总分排序、录入页单科排名+单科备注（服务层补正整数校验）、批量录入页解析历史回看（listParseTasks/getParseTask）、分析页导出 .md（shareFileMessage 降级复制）与 24h 指纹缓存（FNV-1a，原项目 SHA-256 的轻量替代）、line-chart 图例点选隐藏系列、CSV 导出跟随学段/日期筛选、dashboard 首次双刷新修复。过程中修复 findExamsForStats 忽略 includeDraft 的缺陷（见第 9 节）。
- **2026-11-01（晚）**：开发机仓库由 `/root/study-log` 整体迁移至 **`/root/applications/study-log`**（与 cloud-monitor 的目录规划一致）。流程：`deploy/stop.sh` 停服（WAL 安全）→ `mv` 同分区迁移 → `deploy/start.sh` 重启并回归验证（health ok、真实数据完好、小程序 98 项测试通过、git/status 脚本正常）。deploy 脚本按脚本自身位置推断根目录，**零代码修改**；全仓无写死旧路径。ZCode 任务会话索引已同步：`~/.zcode/v2/tasks-index.sqlite`（tasks/project_roots/workspace_alias/session_creation_commands 共 6 行）与 `~/.zcode/v2/setting.json` 的路径由旧改新，旧路径打开项目的历史会话（含本会话）保留；备份在 `~/.zcode/backup/manual-20261101-migrate/`。
- **2026-11-02**：v1.2.0 发布准备并推送 git。①核实工作区既有未提交改动（前端全面注释化、deploy 双模式脚本重组、采用线默认 latest）后全部入库；②修正 gap 正负号 4 处错误文案（`schoolCompare.gapOf` JSDoc、`/schools/compare` notes、目标页图例、docs/02 5.3 示例的 gap 符号），docs/01/02 采用线默认值同步为 latest，docs/02 新增 v1.2.0 修订条目；③版本号 1.1.0→1.2.0（`package.json`、`server/package.json`、`health.js`）；④小程序目录由用户移出本仓库至 `/root/applications/study-log-wxmp`，本文件路径/红线相应更新；⑤`npm test` 全绿后提交并推送 origin/main。本地 nohup 服务未重启（红线），health 的 `version` 字段与目标页图例修正将在下次 `restart.sh --build`/生产部署后生效。
- **2026-11-03**：服务停服排查与运维形态改造。①定位停服根因：11-03 08:59:28 收到 SIGTERM——进程是 11-01 由 AI 会话的 bash 工具用 `nohup` 起的，仍属该会话进程树；ZCode 服务端更新重启清理进程树时整组收到 SIGTERM，而机器上**从未安装过 systemd 单元**（`/etc/systemd/system` 等三处均无），故无人拉起（history 里的 `systemctl stop studylog` 无单元，不是元凶）。②新增 `scripts/start.sh|restart.sh|stop.sh`：统一 systemd 语义，**stop = 永久关闭（stop+disable，重启机器也不自启）**，start/restart 会 `enable` 恢复自启；已实测 stop→ inactive+disabled、start→ active+enabled、`kill -9` → 3s 内自动重生。③`deploy/studylog.service` 改为 `@ROOT@`/`@NODE@` 占位符模板（原文件写死旧路径 `/root/studylog`，在本机装会起不来），新增 `deploy/install-service.sh` 按本机路径渲染安装；本机已安装到 `/etc/systemd/system/studylog.service` 并 enable。④`deploy/start.sh|stop.sh|restart.sh` 降级为转发壳；`deploy/status.sh` 增加开机自启状态与健康检查。⑤`deploy/service.sh` 的 `stray_pids()` 排除 systemd MainPID（否则正常托管进程会被误判为残留）。⑥前端已按 v1.2.0 重新构建并重启，`/api/v1/health` 返回 `version:1.2.0`；数据完好（exam 3 / score 21 / report 1 / school 3，schema_version 4）。⑦README、docs/02 7.5、本文件同步更新。
- **2026-11-03（后半）**：①新增第 0 节「5 分钟上手」与 7.1「生产机部署要点」，补齐跨机器交接所需的事实（单元在仓库外、install-service 的副作用、`git clean -fd` 风险、迁移 004 增量性）；②`deploy/log.sh` 改为从已安装单元解析日志路径（见第 9 节），同时兼容生产的旧单元 `logs/stdout.log`；③远端仓库名 `Study-log` → `study-log`，本地 remote 已更新；④全部改动提交推送 origin/main。
- 更早历史见 `git log`（ff7dab9 debug → e9fb243 增加脚本 → 65e0230/549ecf7/5f00400 界面与导航迭代）与 docs/02 修订记录（v1.0→v1.2 学段维度改版）。
