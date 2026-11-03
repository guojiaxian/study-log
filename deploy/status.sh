#!/usr/bin/env bash
#
# 查看服务运行状态
#   - systemd 模式：单元状态（含 enable/disable 与自启标记）+ 健康检查
#   - nohup 模式  ：PID、内存 + 健康检查
#
# 用法：deploy/status.sh

set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/service.sh"

if unit_exists; then
  systemctl status "$SERVICE" --no-pager -l || true
  echo
  echo "开机自启：$(systemctl is-enabled "$SERVICE" 2>/dev/null || echo unknown)"
  report_health || exit 1
else
  nohup_status || exit 1
fi
