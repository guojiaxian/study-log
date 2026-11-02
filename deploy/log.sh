#!/usr/bin/env bash
#
# 查看服务日志（自适应运行模式）
#   - systemd 模式：journalctl -u studylog
#   - nohup 模式：logs/app.log
#
# 用法：deploy/log.sh [N]        查看最近 N 行（默认 50）
#       tail -f logs/app.log     （nohup 模式）实时跟踪
#       journalctl -u studylog -f（systemd 模式）实时跟踪

set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/service.sh"

N="${1:-50}"
case "$N" in -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

if unit_exists; then
  journalctl -u "$SERVICE" -n "$N" --no-pager
else
  [ -f "$LOG_FILE" ] || { echo "暂无日志文件（$LOG_FILE）"; exit 1; }
  tail -n "$N" "$LOG_FILE"
fi
