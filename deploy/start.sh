#!/usr/bin/env bash
#
# 启动学习记录服务（自适应运行模式）
#   - systemd 单元已安装（生产）→ systemctl start
#   - 其他环境（开发机 nohup）   → PID 文件驱动后台启动
# 已在运行或发现僵死进程时会拒绝重复启动。
#
# 用法：deploy/start.sh

set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/service.sh"

if health_ok; then
  echo "服务已在运行（$HEALTH_URL 健康检查通过），无需启动"
  exit 0
fi

if unit_exists; then
  echo "==> systemctl start $SERVICE"
  systemctl start "$SERVICE" || exit 1
else
  nohup_start || exit 1
  exit 0
fi

# systemd 启动后的健康检查
for _ in $(seq 1 20); do
  if health_ok; then
    echo "健康检查通过：$HEALTH_URL"
    exit 0
  fi
  sleep 1
done
echo "警告：已发出启动命令，但 $HEALTH_URL 未就绪，请用 deploy/log.sh 排查" >&2
exit 1
