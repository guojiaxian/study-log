#!/usr/bin/env bash
# StudyLog 部署脚本（裸机 + systemd）
# 由 Fastify 单进程同时提供 /api/v1 接口与 web/dist 静态页，故部署只需「更新代码 + 重启服务」。
# 流程：拉取代码 → 安装依赖 → 构建前端 → 重启 systemd → 健康检查
#
# 服务器一次性准备（只需做一次，root 身份）：
#   git clone git@github.com:guojiaxian/study-log.git /root/studylog   # 目录可任意，本脚本按自身位置推导
#   cd /root/studylog && cp .env.example .env   # 填入 AI_API_KEY，并 chmod 600 .env
#   scripts/start.sh    # 自动渲染并安装 systemd 单元（deploy/install-service.sh）→ enable → start
#
# 之后每次发版：在服务器上执行  bash deploy/deploy.sh
#
# 前置条件：Node >= 22.5（node:sqlite 需要）、npm、git、curl
set -euo pipefail

# 项目根默认取「本脚本所在目录的上一级」——项目搬家后无需修改本脚本。
# 如需指向别处（例如从外部触发部署），显式传 APP_DIR=/path/to/project。
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${APP_DIR:-$SCRIPT_ROOT}"
SERVICE="${SERVICE:-studylog}"
BRANCH="${BRANCH:-main}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:3000/api/v1/health}"

# 以 root 运行时直接调用 systemctl，避免精简镜像未装 sudo 导致中断
if [ "$(id -u)" -eq 0 ]; then SYSTEMCTL=(systemctl); else SYSTEMCTL=(sudo systemctl); fi

# 安全校验 1：单元里的 WorkingDirectory 必须与本次部署目录一致。
# 项目搬家后若忘记跑 install-service.sh 刷新单元，这里会拦下——否则会「发了新代码、跑的却是旧目录」。
if "${SYSTEMCTL[@]}" cat "$SERVICE" >/dev/null 2>&1; then
  UNIT_DIR="$("${SYSTEMCTL[@]}" cat "$SERVICE" | sed -n 's/^WorkingDirectory=//p' | head -1)"
  if [ -n "$UNIT_DIR" ] && [ "$UNIT_DIR" != "$APP_DIR" ]; then
    echo "错误：systemd 单元的工作目录是 $UNIT_DIR，与本次部署目录 $APP_DIR 不一致。" >&2
    echo "      项目搬过家的话，先执行 $SCRIPT_ROOT/deploy/install-service.sh 刷新单元，再重试本脚本。" >&2
    exit 1
  fi
fi

# 安全校验 2：部署目录必须是 git 仓库（防止 APP_DIR 指错、对空目录执行 reset/clean）
[ -d "$APP_DIR/.git" ] || { echo "错误：$APP_DIR 不是 git 仓库（检查 APP_DIR 是否指错）" >&2; exit 1; }

# Node 版本硬约束：node:sqlite 自 22.5.0 起提供，低于此版本服务无法启动
read -r major minor < <(node -p 'process.versions.node.split(".").slice(0,2).map(Number).join(" ")')
if [ "$major" -lt 22 ] || { [ "$major" -eq 22 ] && [ "$minor" -lt 5 ]; }; then
  echo "错误：需要 Node >= 22.5，当前为 $(node -v)" >&2
  exit 1
fi

cd "$APP_DIR"

# data/logs/backups 均被 .gitignore 排除，不会被下面的清理动作波及
mkdir -p data logs backups

echo "==> 拉取 origin/$BRANCH"
git fetch --prune origin
# 服务器工作区只用于运行，不接受手工改动：直接对齐远端，避免合并冲突
git checkout -f "$BRANCH"
git reset --hard "origin/$BRANCH"
git clean -fd

echo "==> 安装依赖"
npm --prefix server ci --omit=dev
npm --prefix web ci                 # 服务器上构建前端需要 vite，因此同时安装 devDependencies

echo "==> 构建前端"
npm --prefix web run build

echo "==> 重启服务（数据库迁移在进程启动时自动执行）"
"${SYSTEMCTL[@]}" restart "$SERVICE"

echo "==> 健康检查 $HEALTH_URL"
for _ in $(seq 1 15); do
  if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
    echo "部署完成："
    curl -fsS "$HEALTH_URL"; echo
    exit 0
  fi
  sleep 1
done

echo "健康检查失败，请查看日志：journalctl -u $SERVICE -n 50 --no-pager" >&2
exit 1
