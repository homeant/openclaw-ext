#!/usr/bin/env bash
set -euo pipefail

# --- 参数去重函数 ---
dedupe_chrome_args() {
  local -A seen_args=()
  local -a unique_args=()
  for arg in "${CHROME_ARGS[@]}"; do
    if [[ -n "${seen_args["$arg"]:+x}" ]]; then continue; fi
    seen_args["$arg"]=1
    unique_args+=("$arg")
  done
  CHROME_ARGS=("${unique_args[@]}")
}

# --- 环境变量配置 ---
export DISPLAY=:1
export HOME="/tmp/browser-home"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_CACHE_HOME="${HOME}/.cache"

# --- 基础配置变量 ---
CDP_PORT="${BROWSER_CDP_PORT:-9222}"
VNC_PORT="${BROWSER_VNC_PORT:-5900}"
NOVNC_PORT="${BROWSER_NOVNC_PORT:-6080}"
ENABLE_NOVNC="${BROWSER_ENABLE_NOVNC:-1}"
HEADLESS="${BROWSER_HEADLESS:-0}"
ALLOW_NO_SANDBOX="${BROWSER_NO_SANDBOX:-1}"

mkdir -p "${HOME}" "${HOME}/.chrome" "${XDG_CONFIG_HOME}" "${XDG_CACHE_HOME}"

# --- 1. 启动虚拟屏幕 ---
pkill -9 Xvfb || true
Xvfb :1 -screen 0 1366x768x24 -ac -nolisten tcp &

# --- 2. 浏览器参数配置 ---
CHROME_CDP_PORT="$((CDP_PORT + 1))"
CHROME_ARGS=(
  "--remote-debugging-address=127.0.0.1"
  "--remote-debugging-port=${CHROME_CDP_PORT}"
  "--user-data-dir=${HOME}/.chrome"
  "--no-first-run"
  "--window-size=1366,768"
  "--window-position=0,0"
  "--force-device-scale-factor=1"
  "--disable-dev-shm-usage"
)
[[ "${HEADLESS}" == "1" ]] && CHROME_ARGS+=("--headless=new")
[[ "${ALLOW_NO_SANDBOX}" == "1" ]] && CHROME_ARGS+=("--no-sandbox")

dedupe_chrome_args
chromium "${CHROME_ARGS[@]}" "about:blank" &

# --- 3. VNC 认证逻辑修改 ---
VNC_OPTS="-display :1 -rfbport ${VNC_PORT} -shared -forever -listen 0.0.0.0"

if [[ "${ENABLE_NOVNC}" == "1" ]]; then
    # 情况 1 & 2：检查环境变量是否已定义
    if [[ -v BROWSER_VNC_PASSWORD ]]; then
        if [[ -n "${BROWSER_VNC_PASSWORD}" ]]; then
            # 情况 1: 设置了密码且不为空 -> 认证
            echo "检测到自定义密码，启用认证..."
            VNC_PASSWD_FILE="${HOME}/.vnc/passwd"
            mkdir -p "${HOME}/.vnc"
            x11vnc -storepasswd "${BROWSER_VNC_PASSWORD}" "${VNC_PASSWD_FILE}" >/dev/null
            VNC_OPTS+=" -rfbauth ${VNC_PASSWD_FILE}"
        else
            # 情况 2: 设置了变量但为空 "" -> 不认证
            echo "检测到密码环境变量为空，取消认证模式。"
            VNC_OPTS+=" -nopw"
        fi
    else
        # 情况 3: 完全没设置环境变量 -> 自动生成并认证
        echo "未设置密码变量，正在生成临时随机密码..."
        RAND_PASS=$(< /proc/sys/kernel/random/uuid)
        RAND_PASS="${RAND_PASS//-/}"
        RAND_PASS="${RAND_PASS:0:8}"
        VNC_PASSWD_FILE="${HOME}/.vnc/passwd"
        mkdir -p "${HOME}/.vnc"
        x11vnc -storepasswd "${RAND_PASS}" "${VNC_PASSWD_FILE}" >/dev/null
        VNC_OPTS+=" -rfbauth ${VNC_PASSWD_FILE}"
        echo ">>> 临时 VNC 密码为: ${RAND_PASS}"
    fi

    # 启动 x11vnc
    x11vnc ${VNC_OPTS} &
    
    # 启动 noVNC
    if [ -d "/usr/share/novnc/" ]; then
        websockify --web /usr/share/novnc/ "${NOVNC_PORT}" "localhost:${VNC_PORT}" &
    fi
fi

# --- 4. CDP 转发 ---
for _ in $(seq 1 50); do
  if curl -sS --max-time 1 "http://127.0.0.1:${CHROME_CDP_PORT}/json/version" >/dev/null 2>&1; then break; fi
  sleep 0.2
done
socat "TCP-LISTEN:${CDP_PORT},fork,reuseaddr,bind=0.0.0.0" "TCP:127.0.0.1:${CHROME_CDP_PORT}" &

wait -n