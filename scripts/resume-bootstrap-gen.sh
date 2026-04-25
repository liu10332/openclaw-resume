#!/bin/bash
# ========================================
# 生成 bootstrap.sh 到项目状态仓库
# 供新环境一键恢复使用
# 由 resume-init 自动调用
# ========================================

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# 生成 bootstrap.sh
generate_bootstrap() {
    local state_dir="$1"
    local project_name="$2"
    local github_user="${OPENCLAW_RESUME_USER:-your-github-username}"

    cat > "${state_dir}/bootstrap.sh" << 'BOOTSTRAP_EOF'
#!/bin/bash
# ========================================
# openclaw-resume 一键恢复脚本
# 在新的 OpenClaw 试用环境中运行此脚本即可恢复项目
#
# 用法:
#   export OPENCLAW_RESUME_PAT="ghp_你的token"
#   export OPENCLAW_RESUME_USER="你的github用户名"
#   bash bootstrap.sh [project-name]
# ========================================

set -e

PROJECT_NAME="${1:-__PROJECT_NAME__}"
RESUME_REPO="liu10332/openclaw-resume"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_step() { echo -e "${BLUE}[→]${NC} $*"; }
log_info() { echo -e "${GREEN}[✓]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }

# 检查环境变量
if [ -z "${OPENCLAW_RESUME_PAT:-}" ]; then
    echo ""
    echo "请先设置环境变量:"
    echo "  export OPENCLAW_RESUME_PAT=\"ghp_你的token\""
    echo "  export OPENCLAW_RESUME_USER=\"你的github用户名\""
    echo ""
    echo "然后重新运行: bash bootstrap.sh"
    exit 1
fi

if [ -z "${OPENCLAW_RESUME_USER:-}" ]; then
    echo ""
    echo "请设置 GitHub 用户名:"
    echo "  export OPENCLAW_RESUME_USER=\"你的github用户名\""
    echo ""
    exit 1
fi

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║   openclaw-resume 一键恢复               ║"
echo "╚═══════════════════════════════════════════╝"
echo ""

# 1. 安装 openclaw-resume 技能到 OpenClaw 技能目录
log_step "安装 openclaw-resume 技能..."
SKILL_DIR="$HOME/.openclaw/skills/openclaw-resume"

if [ -d "${SKILL_DIR}/.git" ]; then
    log_info "技能已存在，更新中..."
    cd "${SKILL_DIR}" && git pull --quiet 2>/dev/null || true
else
    mkdir -p "$(dirname "${SKILL_DIR}")"
    rm -rf "${SKILL_DIR}" 2>/dev/null
    git clone --quiet "https://${OPENCLAW_RESUME_PAT}@github.com/${RESUME_REPO}.git" "${SKILL_DIR}" 2>/dev/null || \
    git clone --quiet "https://github.com/${RESUME_REPO}.git" "${SKILL_DIR}" 2>/dev/null
    log_info "技能安装完成: ${SKILL_DIR}"
fi

# 2. 加载技能
log_step "加载技能..."
source "${SKILL_DIR}/scripts/core.sh"
source "${SKILL_DIR}/scripts/resume-restore.sh"

# 3. 恢复项目
log_step "恢复项目: ${PROJECT_NAME}..."
echo ""
resume-restore "${PROJECT_NAME}"

echo ""
echo "═══════════════════════════════════════════"
log_info "恢复完成！继续上次的工作吧"
echo ""
echo "  常用命令（已全局可用）:"
echo "    source ${SKILL_DIR}/scripts/core.sh"
echo "    source ${SKILL_DIR}/scripts/resume-save.sh"
echo "    resume-save \"保存进度\""
echo ""
echo "    source ${SKILL_DIR}/scripts/resume-checkpoint.sh"
echo "    resume-checkpoint \"完成xxx\""
echo ""
echo "    source ${SKILL_DIR}/scripts/resume-status.sh"
echo "    resume-status"
echo "═══════════════════════════════════════════"
echo ""
BOOTSTRAP_EOF

    # 替换项目名占位符
    sed -i "s/__PROJECT_NAME__/${project_name}/g" "${state_dir}/bootstrap.sh"
    chmod +x "${state_dir}/bootstrap.sh"

    log_info "已生成 bootstrap.sh"
}
