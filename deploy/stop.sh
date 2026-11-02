#!/usr/bin/env bash
#
# 停止学习记录服务（自适应运行模式）
#   - systemd 单元运行中（生产）              → systemctl stop
#   - nohup 模式（PID 文件）                  → 优雅退出，超时 SIGKILL
#   - 兜底：按「工作目录 = 项目根」扫描残留进程，手动 nohup、丢 PID 文件也能停掉
#
# 用法：deploy/stop.sh

set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/service.sh"

stopped=0

if unit_active; then
  echo "==> systemctl stop $SERVICE"
  systemctl stop "$SERVICE" || exit 1
  echo "已停止（systemd: $SERVICE）"
  stopped=1
elif ! unit_exists; then
  nohup_stop && stopped=1
fi

# 兜底清理残留进程（systemd 停止后仍存活的孤儿、或无单元环境下漏网的）
if pids="$(stray_pids)" && [ -n "$pids" ]; then
  [ "$stopped" -eq 1 ] && echo "发现残留进程，继续清理…"
  echo "停止进程：$pids"
  kill -TERM $pids 2>/dev/null
  for _ in $(seq 1 $((STOP_TIMEOUT * 2))); do
    sleep 0.5
    [ -n "$(stray_pids)" ] || { echo "已停止"; stopped=1; break; }
  done
  if [ -n "$(stray_pids)" ]; then
    echo "优雅退出超时，改用 SIGKILL…"
    kill -KILL $pids 2>/dev/null
    sleep 1
    echo "已强制停止"
    stopped=1
  fi
fi

[ "$stopped" -eq 1 ] || echo "服务未在运行（systemd 无活跃单元，也未发现服务进程）"
