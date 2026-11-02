<script setup>
// ===== 手动录入/编辑成绩页 =====
// 这个页面同时承担两个功能：
//   1. 新增考试：URL 是 /entry/manual
//   2. 编辑已有考试：URL 是 /entry/manual?examId=42（通过 query 参数区分）
// 两种情况共用同一套表单，区别只在提交时是「创建」还是「更新」。

// 从 vue 导入本页用到的核心 API：
//   ref       —— 把变量变成「响应式」的，改它页面自动更新
//   reactive  —— 同样是响应式，但用于整组对象（免 .value，直接改属性）
//   computed  —— 由其他响应式数据「算出来」的缓存值，依赖变了才重算
//   onMounted —— 生命周期钩子：组件第一次出现在页面上时执行（发请求的时机）
import { computed, onMounted, reactive, ref } from 'vue';
// useRoute  读当前路由信息（如 URL 里的 ?examId=42）
// useRouter 拿到路由器实例，用来跳转页面（router.push / router.back）
import { useRoute, useRouter } from 'vue-router';
// api 是统一封装好的后端接口集合（见 ../api/index.js），类比 Python 里的 requests client
import { api } from '../api/index.js';
// GradeChips 是「年级选择按钮组」子组件（初二/初三 两个胶囊按钮）
import GradeChips from '../components/GradeChips.vue';
// fmt 是分数格式化工具（保留小数等）
import { fmt } from '../utils/format.js';

const route = useRoute();
const router = useRouter();

// ---------- 页面状态（全部是响应式变量，改动会自动反映到模板） ----------
const loading = ref(true);        // 是否正在首次加载（控制「加载中…」遮罩）
const saving = ref(false);        // 是否正在保存（防重复点击保存按钮）
const error = ref('');            // 错误提示文案，空串 = 无错误
const subjects = ref([]);         // 当前学段的科目列表（接口返回）
const examTypes = ref([]);        // 考试类型字典（周测/月考/期中/期末…）
const showGrade = ref(false);     // 「不参与总分科目」表格是否展开

// 正在编辑的考试 id：URL 带 ?examId=42 时表示「编辑模式」；否则是新增模式
// route.query.examId 是字符串，Number() 转成数字方便后面比较
const editId = computed(() => (route.query.examId ? Number(route.query.examId) : null));

// 考试的「元信息」表单数据。reactive 包住一个对象后，
// 模板里 v-model="meta.name" 双向绑定输入框：改输入框 → meta.name 变，反之亦然
const meta = reactive({
  name: '',
  examDate: new Date().toISOString().slice(0, 10),
  examType: 'month',
  grade: 9,
  term: '2026-2027-1',
  status: 'confirmed',
  remark: '',
  classRank: null,
  gradeRank: null,
});

// 各科成绩录入行：键是科目 id，值是 { score 得分, absent 是否缺考, level 等级, classRank/gradeRank 单科排名 }
// 注意：reactive({}) 之后「新增/删除键」也能保持响应式，所以换年级时删键是安全的
const rows = reactive({}); // subjectId -> { score, absent, level, classRank, gradeRank }

// 用科目列表初始化录入行；如果是编辑模式，用数据库里已有的成绩（existing）回填
function initRows(list, existing = []) {
  for (const s of list) {
    // existing.find：在已有成绩里找当前科目，找不到返回 undefined（即新增的一科）
    const e = existing.find((x) => x.subjectId === s.id);
    rows[s.id] = {
      score: e && !e.isAbsent ? e.score : null,   // 缺考的科目不回填分数
      absent: e ? !!e.isAbsent : false,           // !! 把 undefined/0 等转成严格的 true/false
      level: e?.gradeLevel ?? null,               // ?. 可选链 + ?? 空值合并：没有就用默认值 null
      classRank: e?.classRank ?? null,
      gradeRank: e?.gradeRank ?? null,
    };
  }
}

// 下面三个 computed 都是「从 subjects / rows 派生出来的值」：
// 科目分两类 —— scoreMode 为 'score' 的按分数录（有满分），
// 'grade' 的按等级录（A/B/C/D，如生物、地理等小科目）
const scoreSubjects = computed(() => subjects.value.filter((s) => s.scoreMode === 'score'));
const gradeSubjects = computed(() => subjects.value.filter((s) => s.scoreMode === 'grade'));
const gradeLabel = computed(() => (Number(meta.grade) === 8 ? '初二' : '初三'));
const GRADE_OPTIONS = [
  { value: 8, label: '初二' },
  { value: 9, label: '初三' },
];

// 已录入科目数（缺考也算「已处理」），用于表头「已录 x/y 科」的进度显示
const enteredCount = computed(
  () => scoreSubjects.value.filter((s) => rows[s.id]?.absent || rows[s.id]?.score != null).length,
);

// 总分实时预览：只累加「计入总分」且「已填分/未缺考」的科目
// 注意 == null 同时匹配 null 和 undefined，是 JS 里判空的惯用写法
const totalPreview = computed(() =>
  scoreSubjects.value.reduce((a, s) => {
    const r = rows[s.id];
    if (!r || r.absent || r.score == null || !s.countsToTotal) return a;
    return a + Number(r.score || 0);
  }, 0),
);

// 当前学段「计入总分」科目的满分合计（如初三 730），用于显示 「xxx / 730」
const cultureFull = computed(() =>
  scoreSubjects.value.filter((s) => s.countsToTotal).reduce((a, s) => a + s.fullScore, 0),
);

// 单科分数校验：非空时必须在 0 ~ 满分 之间；缺考或没填则不算非法
// 返回 true 时模板会给输入框加 invalid 类（红框提示）
function rowInvalid(s) {
  const r = rows[s.id];
  if (!r || r.absent || r.score == null || r.score === '') return false;
  const v = Number(r.score);
  return Number.isNaN(v) || v < 0 || v > s.fullScore;
}

// 编辑模式下暂存的「数据库里已有的成绩」，供 initRows 回填用
// 用普通变量（非响应式）即可：它只作回填数据源，不直接驱动界面
let existingScores = [];

/** 按学段拉取科目字典：初二与初三的科目集合、科目满分不同 */
async function loadSubjects(grade) {
  const subs = await api.subjects(false, grade);
  subjects.value = subs.list;
  meta.grade = Number(grade);
  // 丢掉上一学段独有的科目行（如初三的化学），避免跨学段残留
  const keep = new Set(subs.list.map((s) => s.id));
  for (const k of Object.keys(rows)) if (!keep.has(Number(k))) delete rows[k];
  initRows(subs.list, existingScores);
}

/** 切换学段：换成本学段的科目字典并清空已录值（两学段是各自独立的考试口径） */
// 用户点击了年级选择按钮：如果选的就是当前年级则忽略，否则走切换流程
function onGradePick(v) {
  if (Number(v) === Number(meta.grade)) return;
  onGradeChange(Number(v));
}

// 切换学段的实际处理：清空已有成绩缓存 → 重新拉取该学段的科目并重建录入行
async function onGradeChange(grade) {
  error.value = '';
  try {
    existingScores = [];        // 换学段后旧成绩不再适用，直接清空
    showGrade.value = false;    // 收起「不参与总分科目」表格
    await loadSubjects(grade);
  } catch (e) {
    error.value = e.message;    // 请求失败把错误文案显示到页面顶部的提示条
  }
}

// 首次挂载：拉考试类型字典；编辑模式再拉原考试数据回填；最后按学段拉科目
onMounted(async () => {
  try {
    const types = await api.examTypes();
    examTypes.value = types.list;

    if (editId.value) {
      // 编辑模式：把接口返回的考试信息覆盖到表单初始值上
      const ex = await api.exam(editId.value);
      Object.assign(meta, {   // Object.assign 把右侧对象的属性批量拷进 meta
        name: ex.name, examDate: ex.examDate, examType: ex.examType, grade: ex.grade,
        term: ex.term ?? '', status: ex.status, remark: ex.remark ?? '',
        classRank: ex.classRank, gradeRank: ex.gradeRank,
      });
      existingScores = ex.scores;
      // 如果这次考试录了等级科目，自动展开「不参与总分科目」表格
      if (existingScores.some((s) => s.scoreMode === 'grade')) showGrade.value = true;
    }
    await loadSubjects(meta.grade);   // 不论新增/编辑，都要先有科目列表才能录分
  } catch (e) {
    error.value = e.message;
  } finally {
    loading.value = false;    // 无论成功失败都关掉「加载中…」
  }
});

/** 返回上一页；无历史（直接打开/刷新）时退回管理页 */
function goBack() {
  if (window.history.length > 1) router.back();
  else router.push('/manage');
}

// 提交保存：先做前端校验 → 把录入行整理成接口需要的 scores 数组 → 调创建/更新接口
async function submit() {
  error.value = '';
  // 基本校验：trim() 去掉首尾空格后再判空
  if (!meta.name.trim()) { error.value = '请填写考试名称'; return; }
  if (!meta.examDate) { error.value = '请选择考试日期'; return; }

  // 把 rows（以科目 id 为键的表单数据）转换成后端要求的成绩数组
  const scores = [];
  for (const s of subjects.value) {
    const r = rows[s.id];
    if (!r) continue;                      // 该学段没有这科，跳过
    if (s.scoreMode === 'grade') {         // 等级科目：只提交选中的等级
      if (r.level) scores.push({ subjectId: s.id, gradeLevel: r.level, isAbsent: false });
      continue;
    }
    if (r.absent) { scores.push({ subjectId: s.id, isAbsent: true }); continue; }  // 缺考：只标记，不传分数
    if (r.score == null || r.score === '') continue;   // 没填分的科目不上传（后端按缺录处理）
    if (rowInvalid(s)) { error.value = `${s.name} 得分必须在 0 ~ ${s.fullScore} 之间`; return; }  // 提交前再校验一次
    scores.push({ subjectId: s.id, score: Number(r.score), isAbsent: false, classRank: r.classRank || null });
  }
  if (!scores.length) { error.value = '至少录入一科成绩'; return; }

  // 考试元信息；`x || null` 把空串统一成 null，后端好存储
  const payload = {
    name: meta.name.trim(), examType: meta.examType, examDate: meta.examDate,
    grade: Number(meta.grade), term: meta.term || null, status: meta.status, remark: meta.remark || null,
    classRank: meta.classRank || null, gradeRank: meta.gradeRank || null,
  };

  saving.value = true;   // 置为 true：按钮变「保存中…」并禁用，防止重复提交
  try {
    if (editId.value) {
      // 编辑模式：更新后跳到这场考试的详情页
      await api.updateExam(editId.value, { ...payload, scores });   // ... 是对象展开：合并成一个参数
      router.push(`/exams/${editId.value}`);
    } else {
      // 新增模式：创建成功后接口返回新考试的 id，同样跳到详情页
      const res = await api.createExam({ ...payload, scores });
      router.push(`/exams/${res.examId}`);
    }
  } catch (e) {
    error.value = e.message;   // 失败：显示后端返回的错误信息，停留在本页
  } finally {
    saving.value = false;      // 成功失败都恢复保存按钮
  }
}
</script>

<template>
  <div>
    <!-- 顶部标题栏：editId 有值说明是编辑模式，标题动态显示对应文案 -->
    <div class="card-title">
      <h1>{{ editId ? '编辑成绩' : '手动录入' }}</h1>
      <div class="row" style="gap: 8px">
        <!-- :disabled 绑定 saving：保存请求进行中时禁用按钮，防止重复提交 -->
        <button class="btn btn-primary btn-sm" :disabled="saving" @click="submit">
          {{ saving ? '保存中…' : '保存' }}
        </button>
        <!-- @click 绑定点击事件；href="javascript:void(0)" 让 <a> 不做跳转，纯当按钮用 -->
        <a href="javascript:void(0)" class="btn btn-sm" @click="goBack">← 返回</a>
      </div>
    </div>

    <!-- 条件渲染链：三选一显示 —— 加载中 → 正常内容 -->
    <div v-if="loading" class="loading">加载中…</div>
    <template v-else>
      <!-- error 非空时显示红色错误提示条 -->
      <div v-if="error" class="notice">{{ error }}</div>

      <!-- ======== 卡片一：考试元信息表单 ======== -->
      <div class="card">
        <h2>考试信息</h2>
        <div class="row">
          <!-- v-model 是「双向绑定」：输入框的值和 meta.name 互相联动 -->
          <div class="field" style="flex: 2 1 220px">
            <label>考试名称</label>
            <input v-model="meta.name" placeholder="如：初三上第一次月考" />
          </div>
          <div class="field"><label>考试日期</label><input v-model="meta.examDate" type="date" /></div>
          <!-- v-for 循环渲染考试类型下拉选项；:key 帮 Vue 识别每一项，:value 是选中后存入的值 -->
          <div class="field">
            <label>类型</label>
            <select v-model="meta.examType">
              <option v-for="t in examTypes" :key="t.code" :value="t.code">{{ t.name }}</option>
            </select>
          </div>
          <!-- 子组件 GradeChips：:model-value 传入当前年级，@update:model-value 接收用户的选择 -->
          <div class="field">
            <label>学段</label>
            <GradeChips :model-value="meta.grade" :options="GRADE_OPTIONS" @update:model-value="onGradePick" />
          </div>
          <div class="field"><label>学期</label><input v-model="meta.term" placeholder="2026-2027-1" /></div>
          <div class="field">
            <label>状态</label>
            <select v-model="meta.status"><option value="confirmed">直接确认</option><option value="draft">草稿</option></select>
          </div>
        </div>
        <div class="field"><label>备注</label><input v-model="meta.remark" placeholder="可选" /></div>
      </div>

      <!-- ======== 卡片二：整场考试的排名（可选填写） ======== -->
      <div class="card">
        <div class="card-title">
          <h2>排名信息（成绩单上的排名，可留空）</h2>
          <span class="small muted">班级/年级人数在「管理 → 排名人数设置」中统一维护</span>
        </div>
        <div class="row">
          <div class="field"><label>班级排名</label><input v-model.number="meta.classRank" type="text" inputmode="numeric" autocomplete="off" /></div>
          <div class="field"><label>年级排名</label><input v-model.number="meta.gradeRank" type="text" inputmode="numeric" autocomplete="off" /></div>
        </div>
      </div>

      <!-- ======== 卡片三：逐科成绩明细 ======== -->
      <div class="card">
        <div class="card-title">
          <h2>成绩明细</h2>
          <!-- enteredCount 是 computed：勾选缺考或填了分数就算「已录」，实时更新 -->
          <span class="small muted">已录 {{ enteredCount }}/{{ scoreSubjects.length }} 科</span>
        </div>
        <div class="table-wrap">
          <table class="tbl">
            <thead>
              <tr><th class="l">科目</th><th>{{ gradeLabel }}满分</th><th>得分</th><th>单科班级排名</th><th>缺考</th></tr>
            </thead>
            <tbody>
              <!-- 只渲染按分数录入的科目；等级科目在下方单独一张表 -->
              <tr v-for="s in scoreSubjects" :key="s.id">
                <td class="l">
                  {{ s.name }}
                  <!-- v-if：这科不计入总分时追加一个灰色小标签 -->
                  <span v-if="!s.countsToTotal" class="tag small">不计入总分</span>
                </td>
                <td class="muted">{{ s.fullScore }}</td>
                <td>
                  <!--
                    v-model.number：双向绑定并把输入自动转成数字
                    :class  动态加 invalid 类（rowInvalid(s) 为 true 时红框）
                    :disabled 勾了缺考就禁用得分输入框
                  -->
                  <input
                    v-model.number="rows[s.id].score"
                    type="text" inputmode="decimal" autocomplete="off"
                    :class="{ invalid: rowInvalid(s) }"
                    :disabled="rows[s.id].absent"
                    style="width: 96px"
                  />
                </td>
                <td><input v-model.number="rows[s.id].classRank" type="text" inputmode="numeric" autocomplete="off" style="width: 80px" placeholder="—" /></td>
                <td style="text-align: center"><input v-model="rows[s.id].absent" type="checkbox" style="width: auto" /></td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- 总分实时预览：totalPreview / cultureFull 都是 computed，填分即自动重算 -->
        <div class="row" style="margin-top: 12px; align-items: center">
          <strong>计入总分科目合计：{{ fmt(totalPreview) }} / {{ cultureFull }}</strong>
          <span class="small muted">（本次已录科目合计；{{ gradeLabel }}计入总分满分 {{ cultureFull }}）</span>
        </div>

        <!-- 等级科目区（如生物/地理按 A/B/C/D 评级，不参与总分）：没有这类科目时整块隐藏 -->
        <div v-if="gradeSubjects.length" style="margin-top: 10px">
          <!-- 点击切换 showGrade，箭头和折叠状态跟着变 -->
          <button class="btn btn-sm" @click="showGrade = !showGrade">
            {{ showGrade ? '▾' : '▸' }} 不参与总分科目（{{ gradeSubjects.length }}）{{ gradeSubjects.map((s) => s.name).join('、') }}
          </button>
          <div v-if="showGrade" class="table-wrap" style="margin-top: 10px">
            <table class="tbl">
              <thead><tr><th class="l">科目</th><th>等级</th></tr></thead>
              <tbody>
                <tr v-for="s in gradeSubjects" :key="s.id">
                  <td class="l">{{ s.name }}</td>
                  <td>
                    <select v-model="rows[s.id].level" style="width: 90px">
                      <option :value="null">—</option>
                      <option>A</option><option>B</option><option>C</option><option>D</option>
                    </select>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

    </template>
  </div>
</template>
