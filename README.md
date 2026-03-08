# OpenClaw Browser Extension (sandbox-browser)

OpenClaw 浏览器扩展组件，提供基于 Docker 容器的 Chromium 浏览器沙盒环境，支持 CDP（Chrome DevTools Protocol）、VNC 和 noVNC 访问方式。

## 功能特性

- 🚀 **容器化运行**：基于 Debian Bookworm-slim，轻量且安全
- 🔧 **CDP 支持**：提供 Chrome DevTools Protocol 接口，便于自动化控制
- 🖥️ **VNC 访问**：支持原生 VNC 协议远程桌面访问
- 🌐 **noVNC 支持**：通过浏览器直接访问，无需 VNC 客户端
- 🇨🇳 **中文支持**：内置中文字体和 UTF-8 语言环境
- ⚙️ **灵活配置**：通过环境变量控制浏览器行为
- 🔒 **安全选项**：支持沙盒模式和无头模式切换

## 快速开始

### 1. 构建镜像

```bash
cd sanbox-browser
bash docker-setup.sh
```

### 2. 运行容器

```bash
docker run -d \
  --name sandbox-browser \
  -p 9222:9222 \
  -p 5900:5900 \
  -p 6080:6080 \
  -e BROWSER_NOVNC_PASSWORD=mypassword \
  sandbox-browser:bookworm-slim
```

### 3. 访问浏览器

- **CDP 接口**：`http://localhost:9222`
- **VNC 客户端**：`localhost:5900`
- **noVNC Web**：`http://localhost:6080/vnc.html`

## 环境变量配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `BROWSER_CDP_PORT` | `9222` | CDP 端口（对外暴露） |
| `BROWSER_VNC_PORT` | `5900` | VNC 端口 |
| `BROWSER_NOVNC_PORT` | `6080` | noVNC Web 端口 |
| `BROWSER_ENABLE_NOVNC` | `1` | 是否启用 noVNC（1=启用，0=禁用） |
| `BROWSER_HEADLESS` | `0` | 是否启用无头模式（1=启用，0=禁用） |
| `BROWSER_NO_SANDBOX` | `1` | 是否禁用沙盒（1=禁用，0=启用） |
| `BROWSER_NOVNC_PASSWORD` | （自动生成） | noVNC 密码（空字符串=无认证，未设置=自动生成） |

## VNC 密码策略

脚本提供三种 VNC 认证模式：

1. **设置自定义密码**：`BROWSER_NOVNC_PASSWORD=mypassword`
   - 使用指定密码启用 VNC 认证

2. **禁用认证**：`BROWSER_NOVNC_PASSWORD=""`
   - VNC 无需密码即可访问

3. **自动生成**：不设置 `BROWSER_NOVNC_PASSWORD` 环境变量
   - 自动生成随机密码并在启动时显示

## 系统架构

```
┌─────────────────────────────────────────┐
│         Docker Container                │
│  ┌──────────────────────────────────┐  │
│  │  Xvfb (虚拟屏幕 :1)             │  │
│  │  ┌────────────────────────────┐ │  │
│  │  │  Chromium 浏览器            │ │  │
│  │  │  CDP: 9223 (内部)          │ │  │
│  │  └────────────────────────────┘ │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  x11vnc (VNC 服务器)             │  │
│  │  Port: 5900                     │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  noVNC (Web VNC)                 │  │
│  │  Port: 6080                     │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  socat (CDP 端口转发)            │  │
│  │  9222 → 127.0.0.1:9223          │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## 端口说明

| 端口 | 协议 | 用途 |
|------|------|------|
| 9222 | TCP | Chrome DevTools Protocol（对外） |
| 5900 | TCP | VNC 远程桌面 |
| 6080 | TCP | noVNC Web 访问 |

## 使用示例

### 仅启用 CDP（无 VNC）

```bash
docker run -d \
  --name sandbox-browser-headless \
  -p 9222:9222 \
  -e BROWSER_ENABLE_NOVNC=0 \
  -e BROWSER_HEADLESS=1 \
  sandbox-browser:bookworm-slim
```

### 完整访问（CDP + VNC + noVNC）

```bash
docker run -d \
  --name sandbox-browser-full \
  -p 9222:9222 \
  -p 5900:5900 \
  -p 6080:6080 \
  -e BROWSER_NOVNC_PASSWORD=secure123 \
  sandbox-browser:bookworm-slim
```

### 无认证访问（开发环境）

```bash
docker run -d \
  --name sandbox-browser-dev \
  -p 9222:9222 \
  -p 5900:5900 \
  -p 6080:6080 \
  -e BROWSER_NOVNC_PASSWORD="" \
  sandbox-browser:bookworm-slim
```

## 技术栈

- **基础镜像**：debian:bookworm-slim
- **浏览器**：Chromium（通过 apt 安装）
- **虚拟显示**：Xvfb
- **远程桌面**：x11vnc
- **Web VNC**：noVNC + websockify
- **端口转发**：socat
- **字体**：fonts-wqy-microhei, fonts-wqy-zenhei（中文字体）

## 注意事项

1. **VNC 密码**：生产环境请务必设置 `BROWSER_NOVNC_PASSWORD`
2. **资源限制**：建议根据使用情况设置 Docker 容器的 CPU 和内存限制
3. **网络访问**：容器默认可以访问外部网络，如需隔离请添加网络限制
4. **数据持久化**：如需持久化浏览器数据，请挂载 `~/.chrome` 目录

## 故障排查

### CDP 连接失败

检查 CDP 端口是否正常监听：
```bash
docker exec sandbox-browser curl http://localhost:9223/json/version
```

### VNC 无法连接

1. 确认 VNC 密码是否正确
2. 检查防火墙设置
3. 查看 VNC 服务器日志：
   ```bash
   docker logs sandbox-browser
   ```

### noVNC 显示空白

检查 websockify 是否正常运行：
```bash
docker exec sandbox-browser ps aux | grep websockify
```

## 许可证

本项目遵循 OpenClaw 项目的许可证。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 相关链接

- [OpenClaw](https://github.com/openclaw/openclaw)
- [Chromium](https://www.chromium.org/)
- [noVNC](https://github.com/novnc/noVNC)
- [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/)
