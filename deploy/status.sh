#!/usr/bin/env bash
#
# 查看学习记录服务运行状态（自适应运行模式）
#   - systemd 模式：单元状态 + 健康检查
#   - nohup 模式：PID、内存 + 健康检查
#
# 用法：deploy/status.sh

set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/service.sh"

if unit_exists; then
  systemctl status "$SERVICE" --no-pager -l || true
else
  nohup_status || exit 1
fi
