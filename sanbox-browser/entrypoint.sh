#!/usr/bin/env bash
set -euo pipefail

# --- 环境变量默认值 ---
export DISPLAY=:1
export HOME="~/browser-home"
CDP_PORT="${BROWSER_CDP_PORT:-9222}"
VNC_PORT="${BROWSER_VNC_PORT:-5900}"
NOVNC_PORT="${BROWSER_NOVNC_PORT:-6080}"
ENABLE_NOVNC="${BROWSER_ENABLE_NOVNC:-1}"

# 是否允许不使用沙盒（在 Docker 默认建议设为 1）
ALLOW_NO_SANDBOX="${BROWSER_NO_SANDBOX:-1}"
# 是否禁用图形加速（在无显卡服务器建议设为 1）
DISABLE_GRAPHICS="${BROWSER_DISABLE_GRAPHICS:-1}"
# 启动时的初始 URL
START_URL="${BROWSER_START_URL:-about:blank}"

mkdir -p "${HOME}/.chrome" "${HOME}/.vnc"

# --- 1. 启动虚拟屏幕 ---
Xvfb :1 -screen 0 1920x1200x24 -ac -nolisten tcp &

# --- 2. VNC 认证逻辑 (保持你要求的逻辑) ---
VNC_OPTS="-display :1 -rfbport ${VNC_PORT} -shared -forever -listen 0.0.0.0 -noxdamage"

if [[ "${ENABLE_NOVNC}" == "1" ]]; then
    if [[ -v BROWSER_NOVNC_PASSWORD ]]; then
        if [[ -n "${BROWSER_NOVNC_PASSWORD}" ]]; then
            x11vnc -storepasswd "${BROWSER_NOVNC_PASSWORD}" "${HOME}/.vnc/passwd" >/dev/null
            VNC_OPTS+=" -rfbauth ${HOME}/.vnc/passwd"
        else
            VNC_OPTS+=" -nopw"
        fi
    else
        RAND_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8 || echo "vncpass1")
        echo "Log: 生成随机密码: ${RAND_PASS}"
        x11vnc -storepasswd "${RAND_PASS}" "${HOME}/.vnc/passwd" >/dev/null
        VNC_OPTS+=" -rfbauth ${HOME}/.vnc/passwd"
    fi
    x11vnc ${VNC_OPTS} &
    websockify --web /usr/share/novnc/ "${NOVNC_PORT}" "localhost:${VNC_PORT}" &
fi

# --- 3. 动态构建 Chromium 参数 ---
CHROME_ARGS=(
  "--remote-debugging-address=127.0.0.1"
  "--remote-debugging-port=$((CDP_PORT + 1))"
  "--user-data-dir=${HOME}/.chrome"
  "--window-size=1920,1200"
  "--window-position=0,0"
  "--force-device-scale-factor=1"
  "--disable-dev-shm-usage"
  "--disable-dbus"
  "--disable-notifications"
  "--start-maximized"
)

# 处理是否开启沙盒
if [[ "${ALLOW_NO_SANDBOX}" == "1" ]]; then
  CHROME_ARGS+=("--no-sandbox" "--disable-setuid-sandbox")
fi

# 处理是否禁用图形硬件加速
if [[ "${DISABLE_GRAPHICS}" == "1" ]]; then
  CHROME_ARGS+=("--disable-gpu" "--disable-software-rasterizer" "--disable-3d-apis")
fi

# --- 4. 启动浏览器 ---
chromium "${CHROME_ARGS[@]}" "${START_URL}" &

# --- 5. CDP 转发 ---
sleep 2
socat "TCP-LISTEN:${CDP_PORT},fork,reuseaddr,bind=0.0.0.0" "TCP:127.0.0.1:$((CDP_PORT + 1))" &

echo "Log: 配置完成。CDP:${CDP_PORT}, VNC:${VNC_PORT}, noVNC:${NOVNC_PORT}"
wait -n