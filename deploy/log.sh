#!/usr/bin/env bash
#
# 查看服务日志
#   日志路径从已安装单元的 StandardOutput/StandardError 解析（新旧单元模板都适用）：
#     新模板 → @ROOT@/logs/app.log    旧模板 → /root/studylog/logs/stdout.log
#   解析不到时回退：logs/app.log → journalctl -u studylog
#
# 用法：deploy/log.sh [N]          查看最近 N 行（默认 50）
#       journalctl -u studylog -f  查看 systemd 侧的启停记录

set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/service.sh"

N="${1:-50}"
case "$N" in -h|--help) sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

unit_log_path() {   # 从单元文件里取 append:/path 形式的日志路径（systemd 243 的
                    # `systemctl show -p StandardOutput` 只返回 "append"，拿不到路径）
  systemctl cat "$SERVICE" 2>/dev/null \
    | sed -n 's/^StandardOutput=append://p' \
    | head -1
}

LOG_PATH=""
if unit_exists; then LOG_PATH="$(unit_log_path)"; fi
[ -n "$LOG_PATH" ] || LOG_PATH="$LOG_FILE"

if [ -f "$LOG_PATH" ]; then
  tail -n "$N" "$LOG_PATH"
elif unit_exists; then
  journalctl -u "$SERVICE" -n "$N" --no-pager
else
  echo "暂无日志文件（$LOG_PATH）" >&2
  exit 1
fi
