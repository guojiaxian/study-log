#!/usr/bin/env bash
#
# 启动学习记录服务（systemd 模式，开机自启）
#   - 单元未安装时自动调用 deploy/install-service.sh 安装
#   - 先 enable 再 start：这样在被 scripts/stop.sh 永久关闭后，也能一键恢复自启
#   - 启动后轮询 /api/v1/health，通过才报告成功
#
# 用法：scripts/start.sh

set -uo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../deploy/service.sh"

command -v systemctl >/dev/null 2>&1 || { echo "错误：当前系统没有 systemd" >&2; exit 1; }

# 1) 单元缺失（首次使用 / 代码目录迁移后）→ 自动安装
if ! unit_exists; then
  echo "==> 未检测到 systemd 单元，先执行安装"
  "$ROOT/deploy/install-service.sh" || exit 1
fi

# 2) 清理历史遗留：曾用 nohup 手动启动的进程会与 systemd 抢 3000 端口
if pids="$(stray_pids)" && [ -n "$pids" ]; then
  echo "错误：发现不在 systemd 管理下的服务进程（PID：$pids）" >&2
  echo "      请先执行 scripts/stop.sh 清理，再重新启动" >&2
  exit 1
fi
rm -f "$PID_FILE" 2>/dev/null

# 3) 恢复开机自启 + 启动
echo "==> systemctl enable $SERVICE（开机自启）"
systemctl enable "$SERVICE" >/dev/null 2>&1 || { echo "错误：enable 失败" >&2; exit 1; }

echo "==> systemctl start $SERVICE"
systemctl start "$SERVICE" || {
  echo "启动失败，最近日志：" >&2
  journalctl -u "$SERVICE" -n 20 --no-pager >&2 2>/dev/null || tail -n 20 "$LOG_FILE" >&2
  exit 1
}

# 4) 等就绪
if wait_health 20; then
  echo "启动成功（systemd: $SERVICE，已设为开机自启）"
  report_health
else
  echo "警告：进程已启动，但 $HEALTH_URL 在 20 秒内未响应" >&2
  journalctl -u "$SERVICE" -n 20 --no-pager >&2 2>/dev/null || true
  exit 1
fi
