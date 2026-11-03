#!/usr/bin/env bash
#
# 【已迁移】停止服务统一入口改为 scripts/stop.sh，此脚本仅做转发，保留以兼容旧用法。
#
# 注意：统一后的 stop 是「永久关闭」语义 —— systemctl stop + disable，
#       重启机器也不会自启；恢复请执行 scripts/start.sh。
#
# 用法：deploy/stop.sh    （等价于 scripts/stop.sh）

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "提示：deploy/stop.sh 已迁移，统一使用 scripts/stop.sh（本次自动转发）" >&2
exec "$ROOT/scripts/stop.sh" "$@"
