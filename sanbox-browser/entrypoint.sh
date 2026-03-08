#!/usr/bin/env bash
set -euo pipefail

# --- 1. 环境变量与路径修正 ---
export DISPLAY=:1
# 使用绝对路径，避免 ~ 展开失败
export HOME="/tmp/browser-home"
CDP_PORT="${BROWSER_CDP_PORT:-9222}"
VNC_PORT="${BROWSER_VNC_PORT:-5900}"
NOVNC_PORT="${BROWSER_NOVNC_PORT:-6080}"
ENABLE_NOVNC="${BROWSER_ENABLE_NOVNC:-1}"

# 动态参数
HEADLESS="${BROWSER_HEADLESS:-0}"
ALLOW_NO_SANDBOX="${BROWSER_NO_SANDBOX:-1}"
DISABLE_GRAPHICS="${BROWSER_DISABLE_GRAPHICS:-1}"
START_URL="${BROWSER_START_URL:-about:blank}"

# 创建必要目录
mkdir -p "${HOME}/.chrome" "${HOME}/.vnc"

# --- 2. 强力清理旧环境 (修复 Server already active 报错) ---
echo "Log: 清理旧的 X11 锁文件..."
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 || true
pkill -9 Xvfb chromium x11vnc websockify socat || true

# --- 3. 启动虚拟屏幕 ---
echo "Log: 启动 Xvfb (1368x768)..."
Xvfb :1 -screen 0 1368x768x24 -ac -nolisten tcp &

# 等待 Xvfb 就绪
for i in {1..10}; do
    if timeout 1s xset -display :1 q > /dev/null 2>&1; then
        echo "Log: Xvfb 已成功启动。"
        break
    fi
    echo "Log: 等待 Xvfb 响应..."
    sleep 0.5
done

# --- 4. VNC 与 noVNC 逻辑 ---
if [[ "${ENABLE_NOVNC}" == "1" && "${HEADLESS}" == "0" ]]; then
    VNC_OPTS="-display :1 -rfbport ${VNC_PORT} -shared -forever -listen 0.0.0.0 -noxdamage"
    
    # 逻辑：设置了变量且不为空->认证；设置了变量但为空->不认证；未设置变量->随机生成
    if [[ -v BROWSER_NOVNC_PASSWORD ]]; then
        if [[ -n "${BROWSER_NOVNC_PASSWORD}" ]]; then
            echo "Log: 使用自定义密码认证"
            x11vnc -storepasswd "${BROWSER_NOVNC_PASSWORD}" "${HOME}/.vnc/passwd" >/dev/null
            VNC_OPTS+=" -rfbauth ${HOME}/.vnc/passwd"
        else
            echo "Log: 密码环境变量为空，启用无密码模式"
            VNC_OPTS+=" -nopw"
        fi
    else
        RAND_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8 || echo "vncpass1")
        echo "Log: 未设置密码变量，生成随机密码: ${RAND_PASS}"
        x11vnc -storepasswd "${RAND_PASS}" "${HOME}/.vnc/passwd" >/dev/null
        VNC_OPTS+=" -rfbauth ${HOME}/.vnc/passwd"
    fi
    x11vnc ${VNC_OPTS} &
    
    if [ -d "/usr/share/novnc/" ]; then
        websockify --web /usr/share/novnc/ "${NOVNC_PORT}" "localhost:${VNC_PORT}" &
    fi
fi

# --- 5. 构建 Chromium 参数 ---
CHROME_ARGS=(
  "--remote-debugging-address=127.0.0.1"
  "--remote-debugging-port=$((CDP_PORT + 1))"
  "--user-data-dir=${HOME}/.chrome"
  "--window-size=1366,768"
  "--window-position=0,0"
  "--force-device-scale-factor=1"
  "--disable-dev-shm-usage"
  "--disable-dbus"
  "--disable-notifications"
  "--no-first-run"
  "--ozone-platform=x11"
  "--dbus-stub"
  "--test-type"
)

# 处理 HEADLESS
if [[ "${HEADLESS}" == "1" ]]; then
    echo "Log: 开启 Headless 模式"
    CHROME_ARGS+=("--headless=new")
else
    CHROME_ARGS+=("--start-maximized")
fi

# 处理 NO-SANDBOX
if [[ "${ALLOW_NO_SANDBOX}" == "1" ]]; then
    CHROME_ARGS+=("--no-sandbox")
fi

# 处理 GRAPHICS
if [[ "${DISABLE_GRAPHICS}" == "1" ]]; then
    CHROME_ARGS+=("--disable-gpu" "--disable-software-rasterizer" "--disable-3d-apis")
fi

# --- 6. 启动浏览器 ---
echo "Log: 启动 Chromium..."
chromium "${CHROME_ARGS[@]}" "${START_URL}" &

# --- 7. CDP 转发 ---
# 等待浏览器 CDP 端口开放
echo "Log: 等待浏览器响应调试端口..."
sleep 2
socat "TCP-LISTEN:${CDP_PORT},fork,reuseaddr,bind=0.0.0.0" "TCP:127.0.0.1:$((CDP_PORT + 1))" &

echo "Log: 全部配置完成！"
echo ">> noVNC 端口: ${NOVNC_PORT}"
echo ">> CDP 调试端口: ${CDP_PORT}"
wait -n