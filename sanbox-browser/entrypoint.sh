#!/usr/bin/env bash
set -euo pipefail

# --- 环境变量默认值 ---
export DISPLAY=:1
export HOME="/tmp/browser-home"
CDP_PORT="${BROWSER_CDP_PORT:-9222}"
VNC_PORT="${BROWSER_VNC_PORT:-5900}"
NOVNC_PORT="${BROWSER_NOVNC_PORT:-6080}"
ENABLE_NOVNC="${BROWSER_ENABLE_NOVNC:-1}"

mkdir -p "${HOME}/.chrome" "${HOME}/.vnc"

# --- 1. 启动虚拟屏幕 (使用 1368 避免 VNC 倾斜) ---
Xvfb :1 -screen 0 1368x768x24 -ac -nolisten tcp &

# --- 2. VNC 认证逻辑 ---
VNC_OPTS="-display :1 -rfbport ${VNC_PORT} -shared -forever -listen 0.0.0.0 -noxdamage"

if [[ "${ENABLE_NOVNC}" == "1" ]]; then
    if [[ -v BROWSER_NOVNC_PASSWORD ]]; then
        if [[ -n "${BROWSER_NOVNC_PASSWORD}" ]]; then
            echo "Log: 使用自定义密码认证"
            x11vnc -storepasswd "${BROWSER_NOVNC_PASSWORD}" "${HOME}/.vnc/passwd" >/dev/null
            VNC_OPTS+=" -rfbauth ${HOME}/.vnc/passwd"
        else
            echo "Log: 密码为空，取消认证模式"
            VNC_OPTS+=" -nopw"
        fi
    else
        RAND_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8 || echo "vncpass1")
        echo "Log: 未设置变量，生成随机密码: ${RAND_PASS}"
        x11vnc -storepasswd "${RAND_PASS}" "${HOME}/.vnc/passwd" >/dev/null
        VNC_OPTS+=" -rfbauth ${HOME}/.vnc/passwd"
    fi
    x11vnc ${VNC_OPTS} &
    websockify --web /usr/share/novnc/ "${NOVNC_PORT}" "localhost:${VNC_PORT}" &
fi

# --- 3. 启动浏览器 ---
# 内部端口设为 CDP_PORT + 1
INTERNAL_CDP="$((CDP_PORT + 1))"

chromium \
  --remote-debugging-address=127.0.0.1 \
  --remote-debugging-port=${INTERNAL_CDP} \
  --user-data-dir=${HOME}/.chrome \
  --window-size=1368,768 \
  --window-position=0,0 \
  --force-device-scale-factor=1 \
  --no-sandbox \
  --disable-dev-shm-usage \
  --disable-dbus \
  --disable-gpu \
  --disable-software-rasterizer \
  --start-maximized \
  "about:blank" &

# --- 4. CDP 端口转发 ---
# 等待浏览器就绪后，将 127.0.0.1 转发到 0.0.0.0 以供外部监控
sleep 2
socat "TCP-LISTEN:${CDP_PORT},fork,reuseaddr,bind=0.0.0.0" "TCP:127.0.0.1:${INTERNAL_CDP}" &

echo "Browser is ready on noVNC port ${NOVNC_PORT} and CDP port ${CDP_PORT}"
wait -n