#!/usr/bin/env bash
#
# 【已迁移】重启服务统一入口改为 scripts/restart.sh，此脚本仅做转发，保留以兼容旧用法。
#
# 用法：deploy/restart.sh            仅重启服务（不构建前端）
#       deploy/restart.sh --build    先构建前端再重启（改了页面代码后必须加）

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "提示：deploy/restart.sh 已迁移，统一使用 scripts/restart.sh（本次自动转发）" >&2
exec "$ROOT/scripts/restart.sh" "$@"
