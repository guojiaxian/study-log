#!/usr/bin/env bash
# deploy/service.sh —— 内部公共库：被 start/stop/status/log.sh source，不直接执行。
# 包含两种运行模式的实现：
#   - systemd 模式：单元文件 studylog.service 已安装（生产）
#   - nohup 模式：PID 文件驱动（开发机），日志写 logs/app.log

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE="${STUDYLOG_SERVICE:-studylog}"
PID_FILE="$ROOT/data/studylog.pid"
LOG_FILE="$ROOT/logs/app.log"
STOP_TIMEOUT=15
ENTRY="server/src/server.js"

# ---------------------------------------------------------------- 配置与健康检查

env_value() {   # env_value KEY → 从 .env 取键值（去引号与空白）
  [ -f "$ROOT/.env" ] || return 0
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$ROOT/.env" \
    | tail -1 | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//" -e 's/[[:space:]]*$//'
}

PORT="$(env_value PORT)"; PORT="${PORT:-3000}"
HOST="$(env_value HOST)"; HOST="${HOST:-0.0.0.0}"
case "$HOST" in 0.0.0.0|"::"|"") HEALTH_HOST="127.0.0.1" ;; *) HEALTH_HOST="$HOST" ;; esac
HEALTH_URL="http://$HEALTH_HOST:$PORT/api/v1/health"

health_ok() { curl -fsS --max-time 3 "$HEALTH_URL" >/dev/null 2>&1; }
health_body() { curl -fsS --max-time 3 "$HEALTH_URL" 2>/dev/null; }

# ---------------------------------------------------------------- 模式探测

unit_exists() {  # systemd 单元是否安装（无论启用与否）
  command -v systemctl >/dev/null 2>&1 && systemctl cat "$SERVICE" >/dev/null 2>&1
}
unit_active() { systemctl is-active --quiet "$SERVICE" 2>/dev/null; }

# ---------------------------------------------------------------- 进程识别（nohup 模式）

read_pid() {
  [ -f "$PID_FILE" ] || return 1
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null)"
  [[ "${pid:-}" =~ ^[0-9]+$ ]] || return 1
  printf '%s' "$pid"
}

pid_alive() {   # 进程存在且命令行含本项目入口
  local pid="$1"
  [ -n "$pid" ] && [ -d "/proc/$pid" ] || return 1
  grep -qa -- "$ENTRY" "/proc/$pid/cmdline" 2>/dev/null
}

# 兜底识别：命令行含入口文件 且 进程工作目录 = 项目根（不会误杀其它项目）
stray_pids() {
  local pid cwd
  for pid in $(pgrep -f "${ENTRY//\//\\/}" 2>/dev/null); do
    cwd="$(readlink "/proc/$pid/cwd" 2>/dev/null)" || continue
    [ "$cwd" = "$ROOT" ] && printf '%s\n' "$pid"
  done
}

# ---------------------------------------------------------------- nohup 模式实现

nohup_start() {
  local pid
  if pid="$(read_pid)" && pid_alive "$pid"; then
    echo "服务已在运行（PID $pid，nohup 模式）"
    echo "  访问地址：http://$HEALTH_HOST:$PORT/"
    return 0
  fi
  if pids="$(stray_pids)" && [ -n "$pids" ]; then
    echo "错误：发现服务进程（PID：$pids）但无 PID 记录，请先执行 deploy/stop.sh 清理" >&2
    return 1
  fi

  command -v node >/dev/null 2>&1 || { echo "错误：未找到 node，请先安装 Node ≥ 22.5" >&2; return 1; }
  [ -f "$ROOT/web/dist/index.html" ] \
    || echo "提示：未发现 web/dist/index.html，浏览器访问将无页面，请先 deploy/restart.sh --build"

  mkdir -p "$ROOT/logs" "$ROOT/data"
  echo "启动中…（日志：logs/app.log）"
  nohup node --disable-warning=ExperimentalWarning "$ENTRY" >>"$LOG_FILE" 2>&1 &
  pid=$!
  printf '%s\n' "$pid" >"$PID_FILE"

  local i
  for i in $(seq 1 40); do
    sleep 0.5
    if ! pid_alive "$pid"; then
      echo "启动失败：进程已退出，最近日志："
      tail -n 20 "$LOG_FILE" 2>/dev/null
      rm -f "$PID_FILE"
      return 1
    fi
    if health_ok; then
      echo "启动成功（PID $pid）"
      echo "  访问地址：http://$HEALTH_HOST:$PORT/"
      return 0
    fi
  done
  echo "警告：进程仍在运行，但 $HEALTH_URL 在 20 秒内未响应，请用 deploy/log.sh 排查" >&2
  return 1
}

nohup_stop() {
  local pid pids
  if pid="$(read_pid)" && pid_alive "$pid"; then
    echo "停止中（PID $pid，先 SIGTERM 优雅退出）…"
    kill -TERM "$pid" 2>/dev/null
    local i
    for i in $(seq 1 $((STOP_TIMEOUT * 2))); do
      sleep 0.5
      pid_alive "$pid" || { rm -f "$PID_FILE"; echo "已停止"; return 0; }
    done
    echo "优雅退出超时（${STOP_TIMEOUT}s），改用 SIGKILL…"
    kill -KILL "$pid" 2>/dev/null
    sleep 1
    pid_alive "$pid" && { echo "错误：进程 $pid 未能终止，请手动处理" >&2; return 1; }
    rm -f "$PID_FILE"
    echo "已强制停止"
    return 0
  fi
  rm -f "$PID_FILE"
  # PID 文件缺失（如进程由 systemd 之外的方式手动启动）：按工作目录兜底扫描
  if pids="$(stray_pids)" && [ -n "$pids" ]; then
    echo "停止进程（按项目目录识别）：$pids"
    kill -TERM $pids 2>/dev/null
    local i
    for i in $(seq 1 $((STOP_TIMEOUT * 2))); do
      sleep 0.5
      [ -n "$(stray_pids)" ] || { echo "已停止"; return 0; }
    done
    kill -KILL $pids 2>/dev/null
    sleep 1
    echo "已强制停止"
    return 0
  fi
  echo "服务未在运行"
  return 0
}

nohup_status() {
  local pid
  if ! pid="$(read_pid)" || ! pid_alive "$pid"; then
    echo "状态：未运行"
    return 1
  fi
  echo "状态：运行中（PID $pid，nohup 模式）"
  local rss
  rss="$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ')"
  [ -n "$rss" ] && echo "常驻内存：$((rss / 1024)) MB"
  if command -v curl >/dev/null 2>&1; then
    if body="$(health_body)" && [ -n "$body" ]; then
      echo "健康检查：$body"
    else
      echo "健康检查：失败（$HEALTH_URL 无响应）"
      return 1
    fi
  fi
  echo "访问地址：http://$HEALTH_HOST:$PORT/"
}
