# OpenClaw Extension - sandbox-browser

> OpenClaw 浏览器扩展组件：基于 Docker 容器的 Chromium 浏览器沙盒环境

一个轻量、安全、功能完整的容器化浏览器方案，为 OpenClaw 生态系统提供强大的浏览器自动化和远程访问能力。

## ✨ 核心特性

### 🎯 多协议支持
- **Chrome DevTools Protocol (CDP)**：标准化的浏览器自动化接口
- **VNC 远程桌面**：原生 VNC 协议，支持主流 VNC 客户端
- **noVNC Web 访问**：基于浏览器的 Web VNC 客户端，无需额外软件

### 🛡️ 安全隔离
- 完整的 Docker 容器化隔离
- 可配置的沙盒模式
- 支持无头模式（Headless）
- 灵活的 VNC 密码认证策略

### 🌏 本地化支持
- 内置完整中文字体（WQY 系列）
- UTF-8 编码环境
- 预配置中文 Locale

### ⚙️ 高度可配置
- 通过环境变量控制所有关键参数
- 支持自定义启动 URL
- 灵活的端口映射
- 可选的硬件加速控制

## 🚀 快速开始

### 1. 构建镜像

```bash
cd sanbox-browser
bash docker-setup.sh
```

构建完成后，将生成 `sandbox-browser:bookworm-slim` 镜像。

### 2. 运行容器

#### 完整功能（CDP + VNC + noVNC）

```bash
docker run -d \
  --name sandbox-browser \
  -p 9222:9222 \
  -p 5900:5900 \
  -p 6080:6080 \
  -e BROWSER_NOVNC_PASSWORD=your_secure_password \
  sandbox-browser:bookworm-slim
```

#### 仅 CDP 模式（无界面）

```bash
docker run -d \
  --name sandbox-browser-headless \
  -p 9222:9222 \
  -e BROWSER_ENABLE_NOVNC=0 \
  -e BROWSER_HEADLESS=1 \
  sandbox-browser:bookworm-slim
```

#### 开发环境（无密码）

```bash
docker run -d \
  --name sandbox-browser-dev \
  -p 9222:9222 \
  -p 5900:5900 \
  -p 6080:6080 \
  -e BROWSER_NOVNC_PASSWORD="" \
  sandbox-browser:bookworm-slim
```

### 3. 访问浏览器

| 协议 | 地址 | 说明 |
|------|------|------|
| **CDP** | `http://localhost:9222` | Chrome DevTools Protocol |
| **VNC** | `localhost:5900` | 标准 VNC 客户端 |
| **noVNC** | `http://localhost:6080/vnc.html` | 浏览器直接访问 |

## 📋 环境变量配置

### 核心端口配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `BROWSER_CDP_PORT` | `9222` | CDP 端口（对外暴露） |
| `BROWSER_VNC_PORT` | `5900` | VNC 端口 |
| `BROWSER_NOVNC_PORT` | `6080` | noVNC Web 端口 |

### 功能开关

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `BROWSER_ENABLE_NOVNC` | `1` | 是否启用 noVNC（1=启用，0=禁用） |
| `BROWSER_NO_SANDBOX` | `1` | 是否禁用沙盒（1=禁用，0=启用） |
| `BROWSER_DISABLE_GRAPHICS` | `1` | 是否禁用图形加速（1=禁用，0=启用） |

### 认证与启动

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `BROWSER_NOVNC_PASSWORD` | （自动生成） | VNC 密码 |
| `BROWSER_START_URL` | `about:blank` | 启动时打开的 URL |

### VNC 密码策略

支持三种认证模式：

1. **自定义密码**：设置 `BROWSER_NOVNC_PASSWORD=mypassword`
   ```bash
   docker run -e BROWSER_NOVNC_PASSWORD=secure123 ...
   ```

2. **无密码模式**：设置空字符串 `BROWSER_NOVNC_PASSWORD=""`
   ```bash
   docker run -e BROWSER_NOVNC_PASSWORD="" ...
   ```

3. **自动生成**：不设置该变量（推荐用于快速测试）
   ```bash
   docker run ...  # 密码会在启动日志中显示
   ```

## 🏗️ 系统架构

```
┌─────────────────────────────────────────────────────┐
│              Docker Container                       │
│                                                     │
│  ┌───────────────────────────────────────────────┐ │
│  │  Xvfb (虚拟显示 :1)                           │ │
│  │  Resolution: 1920x1200x24                     │ │
│  │                                               │ │
│  │  ┌─────────────────────────────────────────┐ │ │
│  │  │  Chromium 浏览器                        │ │ │
│  │  │  - CDP: 127.0.0.1:9223 (内部)           │ │ │
│  │  │  - 用户数据: ~/.chrome                   │ │ │
│  │  │  - 窗口: 1920x1200                       │ │ │
│  │  └─────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────┘ │
│                                                     │
│  ┌───────────────────────────────────────────────┐ │
│  │  x11vnc (VNC 服务器)                          │ │
│  │  - Port: 5900                                 │ │
│  │  - 可选密码认证                               │ │
│  │  - 共享模式启用                               │ │
│  └───────────────────────────────────────────────┘ │
│                                                     │
│  ┌───────────────────────────────────────────────┐ │
│  │  noVNC (Web VNC 客户端)                       │ │
│  │  - Port: 6080                                 │ │
│  │  - WebSocket 代理                            │ │
│  └───────────────────────────────────────────────┘ │
│                                                     │
│  ┌───────────────────────────────────────────────┐ │
│  │  socat (端口转发)                             │ │
│  │  - 0.0.0.0:9222 → 127.0.0.1:9223             │ │
│  └───────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

## 💡 使用场景

### 场景 1：自动化测试与爬虫

```bash
docker run -d \
  --name crawler-browser \
  -p 9222:9222 \
  -e BROWSER_ENABLE_NOVNC=0 \
  -e BROWSER_START_URL="https://example.com" \
  sandbox-browser:bookworm-slim
```

使用 CDP 接口进行自动化控制和数据抓取。

### 场景 2：远程桌面监控

```bash
docker run -d \
  --name monitor-browser \
  -p 5900:5900 \
  -p 6080:6080 \
  -e BROWSER_NOVNC_PASSWORD=admin123 \
  -e BROWSER_START_URL="https://dashboard.example.com" \
  sandbox-browser:bookworm-slim
```

通过 VNC 或 noVNC 远程访问监控面板。

### 场景 3：开发调试环境

```bash
docker run -d \
  --name dev-browser \
  -p 9222:9222 \
  -p 5900:5900 \
  -p 6080:6080 \
  -e BROWSER_NOVNC_PASSWORD="" \
  -e BROWSER_NO_SANDBOX=0 \
  -v $(pwd)/browser-data:/home/sandbox/browser-home \
  sandbox-browser:bookworm-slim
```

持久的开发环境，支持数据卷挂载。

### 场景 4：无头自动化

```bash
docker run -d \
  --name headless-browser \
  -p 9222:9222 \
  -e BROWSER_ENABLE_NOVNC=0 \
  -e BROWSER_DISABLE_GRAPHICS=1 \
  sandbox-browser:bookworm-slim
```

完全无头模式，适合 CI/CD 环境。

## 🔧 技术栈

| 组件 | 版本/来源 | 用途 |
|------|-----------|------|
| **基础镜像** | debian:bookworm-slim | 轻量级 Linux 基础环境 |
| **浏览器** | Chromium (apt) | 主浏览器引擎 |
| **虚拟显示** | Xvfb | 无头环境下的虚拟屏幕 |
| **VNC 服务器** | x11vnc | 提供标准 VNC 访问 |
| **Web VNC** | noVNC + websockify | 基于 WebSocket 的 Web VNC |
| **端口转发** | socat | CDP 端口映射 |
| **中文字体** | fonts-wqy-* | 完整中文字符支持 |
| **Shell** | bash | 容器入口脚本 |

## 🐛 故障排查

### CDP 连接失败

**检查 CDP 服务状态：**
```bash
docker exec sandbox-browser curl http://localhost:9223/json/version
```

**检查端口转发：**
```bash
docker exec sandbox-browser ps aux | grep socat
```

### VNC 无法连接

**1. 确认密码是否正确**
```bash
# 查看启动日志中的密码信息
docker logs sandbox-browser
```

**2. 检查 VNC 服务器进程**
```bash
docker exec sandbox-browser ps aux | grep x11vnc
```

**3. 验证端口监听**
```bash
docker exec sandbox-browser netstat -tlnp | grep 5900
```

### noVNC 显示空白或连接失败

**检查 WebSocket 代理：**
```bash
docker exec sandbox-browser ps aux | grep websockify
```

**检查浏览器访问：**
- 确保访问 `http://localhost:6080/vnc.html`（注意路径）
- 检查浏览器控制台是否有 WebSocket 错误

### 容器启动失败

**1. 查看详细日志：**
```bash
docker logs sandbox-browser
```

**2. 检查端口占用：**
```bash
# Linux
netstat -tlnp | grep -E "9222|5900|6080"

# macOS
lsof -i :9222 -i :5900 -i :6080
```

**3. 尝试交互模式调试：**
```bash
docker run -it --rm \
  -p 9222:9222 \
  -p 5900:5900 \
  -p 6080:6080 \
  sandbox-browser:bookworm-slim
```

## 📊 性能优化建议

### 资源限制

```bash
docker run -d \
  --name sandbox-browser \
  --memory="2g" \
  --cpus="2" \
  -p 9222:9222 \
  sandbox-browser:bookworm-slim
```

### 禁用图形加速（无显卡环境）

```bash
docker run -d \
  --name sandbox-browser \
  -e BROWSER_DISABLE_GRAPHICS=1 \
  -p 9222:9222 \
  sandbox-browser:bookworm-slim
```

### 数据持久化

```bash
docker run -d \
  --name sandbox-browser \
  -v $(pwd)/browser-data:/home/sandbox/browser-home \
  -p 9222:9222 \
  sandbox-browser:bookworm-slim
```

## 🔐 安全建议

1. **生产环境务必设置 VNC 密码**
   ```bash
   -e BROWSER_NOVNC_PASSWORD=strong_password_here
   ```

2. **限制网络访问**
   ```bash
   docker run --network=bridge \
     --cap-drop=ALL \
     --cap-add=NET_BIND_SERVICE \
     ...
   ```

3. **只读文件系统**（如果不需要写入）
   ```bash
   docker run --read-only \
     -v /tmp:/tmp \
     -v /home/sandbox/browser-home:rw \
     ...
   ```

4. **使用非 root 用户**
   容器默认使用 `sandbox` 用户，不要切换到 root。

## 🤝 贡献指南

欢迎贡献代码、报告问题或提出建议！

### 开发流程

1. Fork 本仓库
2. 创建特性分支：`git checkout -b feature/your-feature`
3. 提交更改：`git commit -am 'Add some feature'`
4. 推送分支：`git push origin feature/your-feature`
5. 提交 Pull Request

### 代码规范

- Shell 脚本遵循 [ShellCheck](https://www.shellcheck.net/) 规范
- 提交信息使用清晰的描述
- 保持 Dockerfile 最小化原则

## 📝 许可证

本项目遵循 OpenClaw 项目的许可证。

## 🔗 相关资源

- [OpenClaw](https://github.com/openclaw/openclaw) - 核心项目
- [Chromium](https://www.chromium.org/) - 浏览器引擎
- [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/) - 自动化协议
- [noVNC](https://github.com/novnc/noVNC) - Web VNC 客户端
- [x11vnc](https://github.com/LibVNC/x11vnc) - VNC 服务器
- [Xvfb](https://www.x.org/wiki/Development/Xvfb/) - 虚拟显示服务器

## 📧 联系方式

如有问题或建议，请通过以下方式联系：

- 提交 [GitHub Issue](https://github.com/homeant/openclaw-ext/issues)
- 加入 [OpenClaw 社区](https://discord.gg/clawd)

---

**Made with ❤️ by OpenClaw Community**
