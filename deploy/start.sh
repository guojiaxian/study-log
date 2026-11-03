#!/usr/bin/env bash
#
# 【已迁移】启动服务统一入口改为 scripts/start.sh，此脚本仅做转发，保留以兼容旧用法。
# 行为：安装/刷新 systemd 单元（如缺失）→ systemctl enable → start → 健康检查。
#
# 用法：deploy/start.sh    （等价于 scripts/start.sh）

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "提示：deploy/start.sh 已迁移，统一使用 scripts/start.sh（本次自动转发）" >&2
exec "$ROOT/scripts/start.sh" "$@"
