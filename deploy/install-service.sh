#!/usr/bin/env bash
#
# 安装 / 更新 systemd 单元（按本机实际路径渲染 deploy/studylog.service 模板）
#   - 渲染 @ROOT@（项目根）与 @NODE@（node 绝对路径），写入 /etc/systemd/system/
#   - 只做安装与 daemon-reload，不启动、不 enable（启动请用 scripts/start.sh）
#   - 幂等：可反复执行，用于代码目录迁移或 node 路径变化后刷新单元
#
# 用法：sudo deploy/install-service.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE="${STUDYLOG_SERVICE:-studylog}"
UNIT_DIR="/etc/systemd/system"
UNIT_PATH="$UNIT_DIR/$SERVICE.service"
TEMPLATE="$ROOT/deploy/studylog.service"

[ "$(id -u)" -eq 0 ] || { echo "错误：需要 root 权限（systemd 单元写入 $UNIT_DIR）" >&2; exit 1; }
command -v systemctl >/dev/null 2>&1 || { echo "错误：当前系统没有 systemd，无法安装单元" >&2; exit 1; }
[ -f "$TEMPLATE" ] || { echo "错误：模板不存在（$TEMPLATE）" >&2; exit 1; }

NODE="$(command -v node || true)"
[ -n "$NODE" ] || { echo "错误：未找到 node，请先安装 Node ≥ 22.5" >&2; exit 1; }

read -r major minor < <("$NODE" -p 'process.versions.node.split(".").slice(0,2).map(Number).join(" ")')
if [ "$major" -lt 22 ] || { [ "$major" -eq 22 ] && [ "$minor" -lt 5 ]; }; then
  echo "错误：需要 Node ≥ 22.5（node:sqlite），当前为 $("$NODE" -v)" >&2
  exit 1
fi

mkdir -p "$ROOT/logs" "$ROOT/data"

echo "==> 渲染单元：$UNIT_PATH"
echo "    项目根：$ROOT"
echo "    Node  ：$NODE ($("$NODE" -v))"
sed -e "s|@ROOT@|$ROOT|g" -e "s|@NODE@|$NODE|g" "$TEMPLATE" >"$UNIT_PATH"
chmod 644 "$UNIT_PATH"

echo "==> systemctl daemon-reload"
systemctl daemon-reload

echo "已安装 $SERVICE.service（未启动）。启动并设为开机自启用：scripts/start.sh"
