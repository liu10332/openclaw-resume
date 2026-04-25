#!/bin/bash
# ========================================
# openclaw-resume 一键安装脚本
# 用法: curl -sL https://raw.githubusercontent.com/liu10332/openclaw-resume/main/install.sh | bash
# ========================================

set -e

# 配置
REPO="liu10332/openclaw-resume"
BRANCH="main"
RESUME_HOME="${OPENCLAW_RESUME_HOME:-$HOME/.openclaw-resume}"
RESUME_BIN="${RESUME_HOME}/bin"
GITHUB_RAW="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[✓]${NC} $*"; }
log_step()  { echo -e "${BLUE}[→]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║   openclaw-resume 安装程序                ║"
echo "╚═══════════════════════════════════════════╝"
echo ""

# 检查依赖
log_step "检查依赖..."
command -v curl &>/dev/null || { log_error "需要 curl，请先安装"; exit 1; }
command -v git &>/dev/null || { log_error "需要 git，请先安装"; exit 1; }
command -v bash &>/dev/null || { log_error "需要 bash"; exit 1; }

# 创建目录
log_step "创建安装目录..."
mkdir -p "${RESUME_BIN}/scripts"
mkdir -p "${RESUME_HOME}/templates"
mkdir -p "${RESUME_HOME}/config"

# 下载文件列表
FILES=(
    "resume.sh"
    "scripts/core.sh"
    "scripts/resume-init.sh"
    "scripts/resume-restore.sh"
    "scripts/resume-save.sh"
    "scripts/resume-checkpoint.sh"
    "scripts/resume-status.sh"
    "scripts/resume-list.sh"
    "scripts/resume-delete.sh"
    "scripts/env-capture.sh"
    "scripts/env-restore.sh"
    "scripts/resume-timer.sh"
    "scripts/resume-time-remaining.sh"
    "scripts/resume-ask-time.sh"
    "scripts/resume-urgent-save.sh"
    "templates/progress.yaml"
)

# 下载文件
log_step "下载文件..."
FAILED=0
for file in "${FILES[@]}"; do
    local_path="${RESUME_BIN}/${file}"
    mkdir -p "$(dirname "$local_path")"

    # 优先从本地源目录复制（git clone 后安装）
    if [ -f "$(dirname "$0")/${file}" ]; then
        cp "$(dirname "$0")/${file}" "$local_path"
    # 否则从 GitHub 下载
    elif curl -sf --connect-timeout 10 --max-time 30 "${GITHUB_RAW}/${file}" -o "$local_path" 2>/dev/null; then
        : # 下载成功
    else
        log_warn "获取失败: ${file}"
        FAILED=$((FAILED + 1))
        continue
    fi

    # 设置脚本可执行权限
    if [[ "$file" == *.sh ]]; then
        chmod +x "$local_path"
    fi
done

if [ $FAILED -gt 0 ]; then
    log_error "${FAILED} 个文件下载失败"
    log_info "可能是网络问题，请重试，或从 GitHub 手动安装:"
    log_info "  git clone https://github.com/${REPO}.git"
    log_info "  cd openclaw-resume && bash install.sh"
    exit 1
fi

# 创建 resume 命令（symlink 或 wrapper）
log_step "安装 resume 命令..."

RESUME_CMD="${RESUME_BIN}/resume"
cp "${RESUME_BIN}/resume.sh" "$RESUME_CMD"
chmod +x "$RESUME_CMD"

# 尝试加到 PATH
ADDED_TO_PATH=false

# 方式 1：symlink 到 ~/.local/bin
LOCAL_BIN="$HOME/.local/bin"
if [ -d "$LOCAL_BIN" ] || mkdir -p "$LOCAL_BIN" 2>/dev/null; then
    ln -sf "$RESUME_CMD" "$LOCAL_BIN/resume" 2>/dev/null && ADDED_TO_PATH=true
fi

# 方式 2：加到 .bashrc / .zshrc
if ! $ADDED_TO_PATH; then
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            if ! grep -q "$RESUME_BIN" "$rc" 2>/dev/null; then
                echo "" >> "$rc"
                echo "# openclaw-resume" >> "$rc"
                echo "export PATH=\"${RESUME_BIN}:\$PATH\"" >> "$rc"
                ADDED_TO_PATH=true
            fi
        fi
    done
fi

# 方式 3：如果都没有，加到 .bashrc
if ! $ADDED_TO_PATH; then
    echo "" >> "$HOME/.bashrc"
    echo "# openclaw-resume" >> "$HOME/.bashrc"
    echo "export PATH=\"${RESUME_BIN}:\$PATH\"" >> "$HOME/.bashrc"
    ADDED_TO_PATH=true
fi

# 验证安装
log_step "验证安装..."

# 直接测试命令
if "$RESUME_CMD" version &>/dev/null; then
    log_info "命令安装成功"
else
    log_warn "命令验证失败，但文件已安装"
fi

echo ""
echo "═══════════════════════════════════════════"
echo -e "  ${GREEN}✅ 安装完成！${NC}"
echo ""
echo "  📍 安装位置: ${RESUME_BIN}"
echo "  📂 数据目录: ${RESUME_HOME}"
echo ""

# 检查当前 shell 是否能直接用
if command -v resume &>/dev/null; then
    echo "  🚀 resume 命令已可用！"
else
    echo "  ⚠️  请重新加载 shell 配置:"
    echo "     source ~/.bashrc  # 或 source ~/.zshrc"
    echo ""
    echo "  或直接运行:"
    echo "     ${RESUME_CMD} help"
fi

echo ""
echo "  快速开始:"
echo "    export OPENCLAW_RESUME_PAT=\"ghp_你的token\""
echo "    export OPENCLAW_RESUME_USER=\"你的github用户名\""
echo "    resume init my-project"
echo ""
echo "  查看帮助:"
echo "    resume help"
echo "═══════════════════════════════════════════"
echo ""
