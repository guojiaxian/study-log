#!/usr/bin/env bash
#
# 重启学习记录服务（自动适配运行模式）
#
# 用法：deploy/restart.sh          仅重启服务（不构建前端）
#       deploy/restart.sh --build  先构建前端再重启（改了页面代码后必须加）
#
# 说明：Fastify 单进程同时提供接口与 web/dist 静态页，前端改动必须重新构建才会生效。

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

BUILD=0
for arg in "$@"; do
  case "$arg" in
    --build|-b) BUILD=1 ;;
    -h|--help) sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数：$arg" >&2; exit 2 ;;
  esac
done

if [ "$BUILD" -eq 1 ]; then
  echo "==> 构建前端"
  npm run build --prefix "$ROOT/web" || { echo "前端构建失败，已中止重启（服务保持原状）" >&2; exit 1; }
fi

"$ROOT/deploy/stop.sh" || exit 1
sleep 1
"$ROOT/deploy/start.sh" || exit 1
