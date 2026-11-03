#!/usr/bin/env bash
#
# 永久关闭学习记录服务
#   - systemctl stop   ：停止进程
#   - systemctl disable：取消开机自启
#   → 执行后即使重启机器也不会自己起来；要恢复请执行 scripts/start.sh
#
# 这是「永久关闭」语义。若只想临时停一下、重启后仍要自启，
# 请直接使用 systemctl stop studylog（或 deploy/stop.sh 的 systemd 分支）。
#
# 用法：scripts/stop.sh

set -uo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../deploy/service.sh"

command -v systemctl >/dev/null 2>&1 || { echo "错误：当前系统没有 systemd" >&2; exit 1; }

echo "==> systemctl stop $SERVICE"
systemctl stop "$SERVICE" 2>/dev/null || true

echo "==> systemctl disable $SERVICE（取消开机自启）"
# 单元未安装时 disable 会报 Unit not loaded，此处忽略即可：结果同样是「不会自启」
systemctl disable "$SERVICE" >/dev/null 2>&1 || true

# 兜底：清理不在 systemd 管理下的残留进程与陈旧 PID 文件
if pids="$(stray_pids)" && [ -n "$pids" ]; then
  echo "==> 清理残留进程（PID：$pids）"
  kill -TERM $pids 2>/dev/null
  for _ in $(seq 1 $((STOP_TIMEOUT * 2))); do
    sleep 0.5
    [ -n "$(stray_pids)" ] || break
  done
  [ -n "$(stray_pids)" ] && { echo "优雅退出超时，改用 SIGKILL…"; kill -KILL $pids 2>/dev/null; sleep 1; }
fi
rm -f "$PID_FILE" 2>/dev/null

if health_ok; then
  echo "警告：端口仍有服务响应，请检查是否有其它进程占用 $PORT" >&2
  exit 1
fi

echo "已永久关闭：$SERVICE 已停止且取消开机自启（重启机器也不会自启）"
echo "恢复方式：scripts/start.sh"
