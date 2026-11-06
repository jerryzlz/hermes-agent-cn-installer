# Hermes Agent 中国国内镜像安装器

用于在中国大陆网络环境中安装 [Nous Research Hermes Agent](https://github.com/NousResearch/hermes-agent)。

本脚本不修改、不替换、不分发 Hermes Agent 代码，也不会安装社区版、汉化版或第三方修改版。它会下载并执行 Nous Research 官方 `install.sh`，仅将下载来源重定向到国内镜像或加速代理。

## 特性

- 使用 Nous Research 官方安装脚本与官方 GitHub 仓库
- 保留官方 `uv.lock`、依赖版本与 SHA-256 校验
- GitHub、PyPI、Python、npm、Node.js、Playwright/Chromium、Electron 走国内镜像
- 支持透传官方安装器参数
- 内置运行日志、调试日志与失败排查提示

## 安装

```bash
git clone https://github.com/jerryzlz/hermes-agent-cn-installer.git
cd hermes-agent-cn-installer
bash HermesAgentInstall-cn.sh
```

## 常用命令

```bash
# 安装最新 stable release
bash HermesAgentInstall-cn.sh

# 安装桌面端
bash HermesAgentInstall-cn.sh --include-desktop

# 非交互安装，跳过 API key、网关等需要输入的阶段
bash HermesAgentInstall-cn.sh --non-interactive

# 安装官方 main 分支最新提交
bash HermesAgentInstall-cn.sh --channel main

# 启用官方安装器详细日志
bash HermesAgentInstall-cn.sh --verbose

# 启用本引导器调试日志
HERMES_CN_DEBUG=1 bash HermesAgentInstall-cn.sh --verbose
```

## 可配置环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `GH_PROXY` | `https://gh-proxy.com` | GitHub 加速代理，需支持 API、Git Clone 和 Releases |
| `PYPI_INDEX` | `https://mirrors.aliyun.com/pypi/simple/` | PyPI 镜像 |
| `UV_PYTHON_MIRROR` | 由 `GH_PROXY` 生成 | Python 构建产物镜像 |
| `NPM_REGISTRY` | `https://registry.npmmirror.com` | npm 镜像 |
| `NODE_MIRROR` | `https://npmmirror.com/mirrors/node/` | Node.js 二进制镜像 |
| `PLAYWRIGHT_DOWNLOAD_HOST` | `https://cdn.npmmirror.com/binaries/playwright` | Playwright/Chromium 镜像 |
| `ELECTRON_MIRROR` | `https://npmmirror.com/mirrors/electron/` | Electron 镜像 |
| `UV_HTTP_TIMEOUT` | `300` | uv 网络超时时间，单位秒 |
| `HERMES_CN_DEBUG` | `0` | 设为 `1` 启用引导器调试日志 |
| `HERMES_CN_LOG_DIR` | 当前目录下 `hermes-cn-installer-logs` | 引导器日志目录 |

示例：

```bash
GH_PROXY="[https://gh-proxy.com](https://gh-proxy.com)" \
PYPI_INDEX="[https://mirrors.aliyun.com/pypi/simple/](https://mirrors.aliyun.com/pypi/simple/)" \
bash HermesAgentInstall-cn.sh
```

## 日志与排错

引导器日志保存在：

```bash
hermes-cn-installer-logs/install-<时间戳>-<PID>.log
```

查看最新日志：

```bash
tail -n 200 hermes-cn-installer-logs/$(ls -t hermes-cn-installer-logs | head -n 1)
```

查看 Hermes 官方安装器日志：

```bash
tail -n 200 ~/.hermes/logs/install.log
```

安装完成后，如果当前终端找不到 `hermes` 命令：

```bash
export PATH="$HOME/.local/bin:$PATH"
hash -r
hermes --version
```

在 root + SSH 环境中配置网关时，如需启用用户级 systemd：

```bash
loginctl enable-linger root

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"

systemctl --user daemon-reload
hermes gateway install --force
hermes gateway status --deep
```

## 安全说明

- Hermes Agent 代码仍来自官方 GitHub 仓库。
- `uv` 二进制仍按官方 `install.sh` 内置的 SHA-256 校验。
- Python 依赖仍按官方 `uv.lock` 锁定版本与哈希安装。
- 请自行评估所选 GitHub 加速代理的可信度；如对供应链安全有更高要求，建议直连官方源或使用可信企业内网代理。

## License

MIT
