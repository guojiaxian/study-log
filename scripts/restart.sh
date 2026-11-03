#!/usr/bin/env bash
#
# 重启学习记录服务（systemd 模式）
#   scripts/restart.sh           只重启进程（适用于仅改服务端代码）
#   scripts/restart.sh --build   先构建前端再重启（改了 web/ 下代码后必须加：
#                                Fastify 单进程直接托管 web/dist，不重建则不生效）
#
# 与 scripts/stop.sh 不同：restart 会确保单元处于 enable 状态（开机自启），
# 因此被「永久关闭」后执行 restart 也能恢复自启。
#
# 用法：scripts/restart.sh [--build]

set -uo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../deploy/service.sh"

BUILD=0
case "${1:-}" in
  --build) BUILD=1 ;;
  -h|--help) sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "") ;;
  *) echo "未知参数：$1（可用 --build）" >&2; exit 1 ;;
esac

command -v systemctl >/dev/null 2>&1 || { echo "错误：当前系统没有 systemd" >&2; exit 1; }

if ! unit_exists; then
  echo "==> 未检测到 systemd 单元，先执行安装"
  "$ROOT/deploy/install-service.sh" || exit 1
fi

if [ "$BUILD" -eq 1 ]; then
  echo "==> 构建前端（npm --prefix web run build）"
  if ! (cd "$ROOT" && npm --prefix web run build); then
    echo "构建失败：已中止重启，服务保持原状" >&2
    exit 1
  fi
fi

if pids="$(stray_pids)" && [ -n "$pids" ]; then
  echo "错误：发现不在 systemd 管理下的服务进程（PID：$pids）" >&2
  echo "      请先执行 scripts/stop.sh 清理，再重新启动" >&2
  exit 1
fi
rm -f "$PID_FILE" 2>/dev/null

echo "==> systemctl enable $SERVICE"
systemctl enable "$SERVICE" >/dev/null 2>&1 || true

echo "==> systemctl restart $SERVICE"
systemctl restart "$SERVICE" || {
  echo "重启失败，最近日志：" >&2
  journalctl -u "$SERVICE" -n 20 --no-pager >&2 2>/dev/null || tail -n 20 "$LOG_FILE" >&2
  exit 1
}

if wait_health 20; then
  echo "重启成功（systemd: $SERVICE）"
  report_health
else
  echo "警告：进程已重启，但 $HEALTH_URL 在 20 秒内未响应" >&2
  journalctl -u "$SERVICE" -n 20 --no-pager >&2 2>/dev/null || true
  exit 1
fi
