#!/usr/bin/env bash
#
# Hermes Agent 中国国内镜像安装引导器
#
# 功能：
#   1. 下载并执行 Nous Research 官方 Hermes Agent install.sh；
#   2. 仅将 GitHub、PyPI、Python、npm、Node.js、Playwright、Electron 的下载
#      来源重定向到国内镜像或加速代理；
#   3. 不使用 fork、社区版、汉化版或任何第三方修改版；
#   4. 保留官方安装阶段、uv 锁定版本、SHA-256 校验和更新逻辑。
#
# 官方安装脚本：
#   https://hermes-agent.nousresearch.com/install.sh
#
# 用法：
#   bash HermesAgentInstall-cn.sh
#   bash HermesAgentInstall-cn.sh --include-desktop
#   bash HermesAgentInstall-cn.sh --non-interactive
#   bash HermesAgentInstall-cn.sh --verbose
#
# 调试：
#   HERMES_CN_DEBUG=1 bash HermesAgentInstall-cn.sh --verbose
#
# License: MIT
#

set -Eeuo pipefail

###############################################################################
# 可配置镜像
###############################################################################

# GitHub 加速代理。
# 必须支持：
#   - GitHub REST API（api.github.com）
#   - Git Clone / Fetch
#   - Releases 与 Release Assets
GH_PROXY="${GH_PROXY:-https://gh-proxy.com}"

# PyPI 镜像。默认使用阿里云；可改为清华 TUNA、中科大等。
PYPI_INDEX="${PYPI_INDEX:-https://mirrors.aliyun.com/pypi/simple/}"

# uv 使用的 Python 构建产物镜像。
# 仍下载 astral-sh/python-build-standalone 的官方 Release。
UV_PYTHON_MIRROR="${UV_PYTHON_MIRROR:-${GH_PROXY}/https://github.com/astral-sh/python-build-standalone/releases/download}"

# npm 官方包的国内公共镜像。
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"

# Node.js 官方二进制镜像。
NODE_MIRROR="${NODE_MIRROR:-https://npmmirror.com/mirrors/node/}"

# Playwright / Chromium 官方浏览器二进制镜像。
PLAYWRIGHT_DOWNLOAD_HOST="${PLAYWRIGHT_DOWNLOAD_HOST:-https://cdn.npmmirror.com/binaries/playwright}"

# Electron 官方二进制镜像；仅在 --include-desktop 构建桌面端时相关。
ELECTRON_MIRROR="${ELECTRON_MIRROR:-https://npmmirror.com/mirrors/electron/}"

# 官方 Hermes Agent 安装脚本地址。
OFFICIAL_INSTALL_URL="${OFFICIAL_INSTALL_URL:-https://hermes-agent.nousresearch.com/install.sh}"

# GitHub API 预检地址：官方 install.sh 使用它查询最新 stable release。
GITHUB_API_RELEASE_URL="https://api.github.com/repos/NousResearch/hermes-agent/releases/latest"

###############################################################################
# 日志与调试
###############################################################################

# 是否启用调试日志：
#   HERMES_CN_DEBUG=1 bash HermesAgentInstall-cn.sh
HERMES_CN_DEBUG="${HERMES_CN_DEBUG:-0}"

# 运行日志目录。
LOG_DIR="${HERMES_CN_LOG_DIR:-$PWD/hermes-cn-installer-logs}"
mkdir -p "$LOG_DIR"

# 每次运行生成独立日志，便于排查。
RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"
LOG_FILE="$LOG_DIR/install-$RUN_ID.log"

# 同时输出到终端与日志文件。
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
  printf '\033[1;36m==>\033[0m %s\n' "$*"
}

log_ok() {
  printf '\033[1;32m✓\033[0m %s\n' "$*"
}

log_warn() {
  printf '\033[1;33m⚠\033[0m %s\n' "$*"
}

log_error() {
  printf '\033[1;31m✗\033[0m %s\n' "$*" >&2
}

debug() {
  # 只有 HERMES_CN_DEBUG=1 时输出调试信息。
  if [ "$HERMES_CN_DEBUG" = "1" ]; then
    printf '\033[1;35m[DEBUG]\033[0m %s\n' "$*"
  fi
}

# 任何未捕获错误时，输出出错行、命令与日志位置。
on_error() {
  local exit_code=$?
  local line_no=${1:-unknown}
  local command_text=${2:-unknown}

  log_error "安装引导器在第 $line_no 行失败。"
  log_error "失败命令：$command_text"
  log_error "退出码：$exit_code"
  log_error "完整日志：$LOG_FILE"

  if [ -f "$LOG_FILE" ]; then
    log_warn "日志最后 30 行："
    tail -n 30 "$LOG_FILE" >&2 || true
  fi

  log_warn "排查建议："
  log_warn "  1. 使用详细模式重跑：HERMES_CN_DEBUG=1 bash HermesAgentInstall-cn.sh --verbose"
  log_warn "  2. 更换 GitHub 加速节点：GH_PROXY=\"https://gh-proxy.com\" bash HermesAgentInstall-cn.sh"
  log_warn "  3. 更换 PyPI 镜像：PYPI_INDEX=\"https://mirrors.aliyun.com/pypi/simple/\" bash HermesAgentInstall-cn.sh"
  log_warn "  4. 查看官方安装日志：tail -n 200 ~/.hermes/logs/install.log"

  exit "$exit_code"
}

trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

###############################################################################
# 基础检查
###############################################################################

log "开始 Hermes Agent 中国国内镜像安装"
debug "运行 ID：$RUN_ID"
debug "日志文件：$LOG_FILE"
debug "GH_PROXY=$GH_PROXY"
debug "PYPI_INDEX=$PYPI_INDEX"
debug "UV_PYTHON_MIRROR=$UV_PYTHON_MIRROR"
debug "NPM_REGISTRY=$NPM_REGISTRY"
debug "NODE_MIRROR=$NODE_MIRROR"
debug "PLAYWRIGHT_DOWNLOAD_HOST=$PLAYWRIGHT_DOWNLOAD_HOST"
debug "ELECTRON_MIRROR=$ELECTRON_MIRROR"

command -v curl >/dev/null 2>&1 || {
  log_error "缺少 curl。请先安装 curl。"
  exit 1
}

command -v git >/dev/null 2>&1 || {
  log_error "缺少 git。请先安装 git。"
  exit 1
}

command -v bash >/dev/null 2>&1 || {
  log_error "缺少 bash。请使用 Bash 运行本脚本。"
  exit 1
}

log_ok "基础依赖检查通过：curl、git、bash"

###############################################################################
# curl 镜像包装器
###############################################################################

# 创建临时 curl 包装器：
#   - 仅重写 GitHub 相关域名；
#   - 不改写 Hermes 官方域名、PyPI 镜像、npmmirror 等地址；
#   - 透传全部 curl 参数，保留官方脚本的重定向、超时和错误处理。
SHIM_DIR="$(mktemp -d)"
cleanup() {
  debug "清理临时目录：$SHIM_DIR"
  rm -rf "$SHIM_DIR"
}
trap cleanup EXIT

REAL_CURL="$(command -v curl)"

cat > "$SHIM_DIR/curl" <<EOF
#!/usr/bin/env bash
set -euo pipefail

args=()

for arg in "\$@"; do
  case "\$arg" in
    https://github.com/*|\
    https://api.github.com/*|\
    https://objects.githubusercontent.com/*|\
    https://raw.githubusercontent.com/*|\
    https://codeload.github.com/*)
      rewritten="${GH_PROXY}/\$arg"
      args+=("\$rewritten")
      ;;
    *)
      args+=("\$arg")
      ;;
  esac
done

exec "${REAL_CURL}" "\${args[@]}"
EOF

chmod +x "$SHIM_DIR/curl"

export PATH="$SHIM_DIR:$PATH"

debug "已启用 curl 镜像包装器：$SHIM_DIR/curl"
debug "PATH=$PATH"

###############################################################################
# Git 镜像配置
###############################################################################

# Git 仍使用官方仓库地址。
# 通过进程级 insteadOf 规则，把官方 GitHub URL 映射到加速代理。
#
# 正确格式：
#   url.https://gh-proxy.com/https://github.com/.insteadOf = https://github.com/
#
# 这样官方脚本中的 is_official_repo 判断仍然识别官方仓库，
# stable release、tag 拉取与后续 hermes update 的逻辑不受影响。
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="url.${GH_PROXY}/https://github.com/.insteadOf"
export GIT_CONFIG_VALUE_0="https://github.com/"

debug "GIT_CONFIG_KEY_0=$GIT_CONFIG_KEY_0"
debug "GIT_CONFIG_VALUE_0=$GIT_CONFIG_VALUE_0"

###############################################################################
# Python / uv / Node / 浏览器镜像
###############################################################################

export UV_PYTHON_INSTALL_MIRROR="$UV_PYTHON_MIRROR"
export UV_PYTHON_DOWNLOADS="automatic"
export UV_NO_CONFIG=1

export UV_DEFAULT_INDEX="$PYPI_INDEX"
export UV_INDEX_URL="$PYPI_INDEX"
export PIP_INDEX_URL="$PYPI_INDEX"
export UV_HTTP_TIMEOUT="${UV_HTTP_TIMEOUT:-300}"

export npm_config_registry="$NPM_REGISTRY"
export NPM_CONFIG_REGISTRY="$NPM_REGISTRY"

export NODEJS_ORG_MIRROR="$NODE_MIRROR"
export NVM_NODEJS_ORG_MIRROR="$NODE_MIRROR"
export NODE_MIRROR="$NODE_MIRROR"
export NODE_DOWNLOAD_URL="$NODE_MIRROR"

export PLAYWRIGHT_DOWNLOAD_HOST="$PLAYWRIGHT_DOWNLOAD_HOST"
export ELECTRON_MIRROR="$ELECTRON_MIRROR"
export ELECTRON_CUSTOM_DIR="${ELECTRON_CUSTOM_DIR:-{{ version }}}"

debug "UV_PYTHON_INSTALL_MIRROR=$UV_PYTHON_INSTALL_MIRROR"
debug "UV_DEFAULT_INDEX=$UV_DEFAULT_INDEX"
debug "UV_HTTP_TIMEOUT=$UV_HTTP_TIMEOUT"
debug "npm_config_registry=$npm_config_registry"
debug "NODEJS_ORG_MIRROR=$NODEJS_ORG_MIRROR"
debug "PLAYWRIGHT_DOWNLOAD_HOST=$PLAYWRIGHT_DOWNLOAD_HOST"
debug "ELECTRON_MIRROR=$ELECTRON_MIRROR"

###############################################################################
# GitHub API 预检
###############################################################################

log "检测 GitHub 加速镜像：$GH_PROXY"

API_PROBE_URL="${GH_PROXY}/${GITHUB_API_RELEASE_URL}"
API_PROBE_RESULT="$SHIM_DIR/github-api-probe.json"

debug "GitHub API 预检地址：$API_PROBE_URL"

# 注意：
#   不能使用 `curl | grep -q`。
#   grep -q 匹配后立即退出并关闭管道，curl 会报 “Failed writing body”，
#   在 pipefail 下会被误判为镜像故障。
set +e
"$REAL_CURL" \
  -fsSL \
  --connect-timeout 10 \
  --max-time 30 \
  -H 'Accept: application/vnd.github+json' \
  "$API_PROBE_URL" \
  -o "$API_PROBE_RESULT"
CURL_PROBE_STATUS=$?
set -e

debug "curl 预检退出码：$CURL_PROBE_STATUS"

if [ "$CURL_PROBE_STATUS" -ne 0 ]; then
  log_error "GitHub 加速镜像请求失败。"
  log_error "测试地址：$API_PROBE_URL"
  log_error "curl 退出码：$CURL_PROBE_STATUS"

  if [ -s "$API_PROBE_RESULT" ]; then
    log_warn "镜像返回内容前 20 行："
    head -n 20 "$API_PROBE_RESULT" >&2 || true
  fi

  log_error "请更换支持 GitHub API 的加速节点，例如："
  log_error "  GH_PROXY=\"https://gh-proxy.com\" bash HermesAgentInstall-cn.sh"
  exit 1
fi

if [ ! -s "$API_PROBE_RESULT" ]; then
  log_error "GitHub 加速镜像返回空响应。"
  log_error "测试地址：$API_PROBE_URL"
  exit 1
fi

if ! grep -q '"tag_name"' "$API_PROBE_RESULT"; then
  log_error "GitHub 加速镜像返回内容异常，未找到 tag_name 字段。"
  log_error "测试地址：$API_PROBE_URL"
  log_warn "响应内容前 30 行："
  head -n 30 "$API_PROBE_RESULT" >&2 || true
  exit 1
fi

DETECTED_TAG="$(grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$API_PROBE_RESULT" \
  | head -n 1 \
  | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"

log_ok "GitHub 加速镜像可用；检测到最新 stable release：$DETECTED_TAG"

###############################################################################
# 下载并执行官方安装脚本
###############################################################################

log "下载 Nous Research 官方 Hermes Agent 安装脚本"
debug "官方脚本地址：$OFFICIAL_INSTALL_URL"

OFFICIAL_SCRIPT="$SHIM_DIR/hermes-official-install.sh"

set +e
"$REAL_CURL" \
  -fsSL \
  --connect-timeout 15 \
  --max-time 60 \
  "$OFFICIAL_INSTALL_URL" \
  -o "$OFFICIAL_SCRIPT"
OFFICIAL_DOWNLOAD_STATUS=$?
set -e

if [ "$OFFICIAL_DOWNLOAD_STATUS" -ne 0 ]; then
  log_error "官方 Hermes Agent 安装脚本下载失败。"
  log_error "下载地址：$OFFICIAL_INSTALL_URL"
  log_error "curl 退出码：$OFFICIAL_DOWNLOAD_STATUS"
  exit 1
fi

if [ ! -s "$OFFICIAL_SCRIPT" ]; then
  log_error "官方 Hermes Agent 安装脚本为空。"
  log_error "下载地址：$OFFICIAL_INSTALL_URL"
  exit 1
fi

if ! head -n 1 "$OFFICIAL_SCRIPT" | grep -q 'usr/bin/env bash'; then
  log_error "下载内容不是有效的 Bash 安装脚本。"
  log_error "下载地址：$OFFICIAL_INSTALL_URL"
  log_warn "文件前 10 行："
  head -n 10 "$OFFICIAL_SCRIPT" >&2 || true
  exit 1
fi

log_ok "官方 Hermes Agent 安装脚本下载完成"

log "使用国内镜像执行官方 Hermes Agent 安装程序"
debug "传递给官方安装器的参数：$*"

# 执行官方脚本；所有命令行参数原样透传。
bash "$OFFICIAL_SCRIPT" "$@"

###############################################################################
# 安装后提示
###############################################################################

log_ok "Hermes Agent 中国国内镜像安装流程结束"

cat <<EOF

后续提示：

  1. 如果当前终端找不到 hermes 命令，请执行：
       export PATH="\$HOME/.local/bin:\$PATH"
       hash -r

  2. 如果在 root + SSH 环境中配置网关失败，请先启用用户级 systemd：
       loginctl enable-linger root
       export XDG_RUNTIME_DIR="/run/user/\$(id -u)"
       export DBUS_SESSION_BUS_ADDRESS="unix:path=\$XDG_RUNTIME_DIR/bus"
       systemctl --user daemon-reload

  3. 然后安装或修复网关：
       hermes gateway install --force
       hermes gateway status --deep

  4. 官方安装日志：
       tail -n 200 ~/.hermes/logs/install.log

  5. 本引导器日志：
       $LOG_FILE

EOF