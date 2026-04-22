#!/bin/bash
# ========================================
# openclaw-resume 一键初始化
# 用法: bash quick-init.sh <项目名> [工作目录] [PAT] [GitHub用户名]
#
# 示例:
#   bash quick-init.sh my-project
#   bash quick-init.sh my-project /path/to/code
#   bash quick-init.sh my-project /path/to/code ghp_xxxx your-username
# ========================================

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[✓]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }
log_step()  { echo -e "${BLUE}[→]${NC} $*"; }

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║   openclaw-resume 一键初始化               ║"
echo "╚═══════════════════════════════════════════╝"
echo ""

# ========================================
# 参数解析
# ========================================
PROJECT_NAME="${1:-}"
WORKSPACE_DIR="${2:-.}"
PAT="${3:-${OPENCLAW_RESUME_PAT:-}}"
GITHUB_USER="${4:-${OPENCLAW_RESUME_USER:-}}"
RESUME_BASE="${OPENCLAW_RESUME_BASE:-$HOME/.openclaw-resume}"

if [ -z "$PROJECT_NAME" ]; then
    echo "用法: bash quick-init.sh <项目名> [工作目录] [PAT] [GitHub用户名]"
    echo ""
    echo "参数:"
    echo "  项目名      项目名称（英文，用连字符分隔）"
    echo "  工作目录    要同步的代码目录（默认当前目录）"
    echo "  PAT         GitHub Personal Access Token"
    echo "  GitHub用户名  GitHub 用户名"
    echo ""
    echo "环境变量（可替代命令行参数）:"
    echo "  OPENCLAW_RESUME_PAT    GitHub PAT"
    echo "  OPENCLAW_RESUME_USER   GitHub 用户名"
    exit 1
fi

# 转换为绝对路径
WORKSPACE_DIR="$(cd "$WORKSPACE_DIR" 2>/dev/null && pwd)" || {
    log_error "工作目录不存在: $WORKSPACE_DIR"
    exit 1
}

# ========================================
# 交互式获取缺失信息
# ========================================
if [ -z "$PAT" ]; then
    echo -n "GitHub Personal Access Token: "
    read -rs PAT
    echo ""
    [ -z "$PAT" ] && { log_error "PAT 不能为空"; exit 1; }
fi

if [ -z "$GITHUB_USER" ]; then
    echo -n "GitHub 用户名: "
    read -r GITHUB_USER
    [ -z "$GITHUB_USER" ] && { log_error "用户名不能为空"; exit 1; }
fi

# ========================================
# 前置检查
# ========================================
log_step "检查环境..."

if ! command -v git &>/dev/null; then
    log_error "git 未安装"
    exit 1
fi

# 设置 git
git config --global user.email "${GITHUB_USER}@local" 2>/dev/null || true
git config --global user.name "$GITHUB_USER" 2>/dev/null || true
export GIT_TERMINAL_PROMPT=0
git config --global http.postBuffer 524288000 2>/dev/null || true

# 验证 PAT
log_step "验证 GitHub PAT..."
HTTP_CODE=$(timeout 10 curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: token $PAT" \
    "https://api.github.com/user" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    log_info "PAT 验证通过"
elif [ "$HTTP_CODE" = "401" ]; then
    log_error "PAT 无效或已过期"
    exit 1
elif [ "$HTTP_CODE" = "000" ]; then
    log_warn "无法连接 GitHub（网络问题），继续尝试..."
else
    log_warn "GitHub API 返回 $HTTP_CODE，继续尝试..."
fi

# ========================================
# 创建 GitHub 仓库
# ========================================
REPO_NAME="${PROJECT_NAME}-state"
STATE_DIR="${RESUME_BASE}/${PROJECT_NAME}"

log_step "创建 GitHub 仓库: ${REPO_NAME}..."
REPO_RESULT=$(timeout 15 curl -s -H "Authorization: token $PAT" \
    -d "{\"name\":\"${REPO_NAME}\",\"private\":true,\"description\":\"openclaw-resume: ${PROJECT_NAME}\"}" \
    "https://api.github.com/user/repos" 2>/dev/null)

if echo "$REPO_RESULT" | grep -q '"full_name"'; then
    log_info "仓库创建成功: ${GITHUB_USER}/${REPO_NAME}"
elif echo "$REPO_RESULT" | grep -q 'already_exists'; then
    log_warn "仓库已存在，将使用现有仓库"
else
    log_warn "仓库创建结果不确定，继续..."
fi

# ========================================
# 初始化本地状态目录
# ========================================
log_step "初始化本地状态目录..."
mkdir -p "$STATE_DIR/environment" "$STATE_DIR/workspace" "$STATE_DIR/checkpoints"

CLONE_URL="https://${PAT}@github.com/${GITHUB_USER}/${REPO_NAME}.git"

# 尝试克隆
if timeout 15 git clone "$CLONE_URL" "$STATE_DIR" 2>/dev/null; then
    log_info "仓库克隆成功"
else
    log_info "仓库为空，本地初始化..."
    rm -rf "$STATE_DIR" 2>/dev/null
    mkdir -p "$STATE_DIR/environment" "$STATE_DIR/workspace" "$STATE_DIR/checkpoints"
    git -C "$STATE_DIR" init -b main
    git -C "$STATE_DIR" remote add origin "$CLONE_URL"
fi

# ========================================
# 生成 progress.yaml
# ========================================
log_step "生成进度文件..."

SESSION_ID="$(date +%Y-%m-%d)-am-1"
NOW="$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")"
EXPIRES="$(date -d "+60 minutes" -Iseconds 2>/dev/null || date -v+60M +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null || echo "unknown")"

cat > "$STATE_DIR/progress.yaml" << EOF
# openclaw-resume 进度追踪文件
session:
  id: "${SESSION_ID}"
  started: "${NOW}"
  expires_at: "${EXPIRES}"
  last_saved: "${NOW}"

position:
  project: "${PROJECT_NAME}"
  project_desc: ""
  task: ""
  step: "0"
  total_steps: "0"
  note: ""

log:
  - "$(date +%H:%M) 项目初始化完成（本地）"

checkpoints: []

todo: []
EOF

# ========================================
# 同步工作文件
# ========================================
log_step "同步工作文件..."
WORKSPACE_DST="${STATE_DIR}/workspace"

if command -v rsync &>/dev/null; then
    rsync -a --delete \
        --exclude='node_modules' \
        --exclude='__pycache__' \
        --exclude='.venv' \
        --exclude='.git' \
        --exclude='*.pyc' \
        --exclude='.openclaw-resume' \
        "$WORKSPACE_DIR/" "$WORKSPACE_DST/" 2>/dev/null || true
else
    cp -r "$WORKSPACE_DIR"/* "$WORKSPACE_DST/" 2>/dev/null || true
fi
log_info "工作文件已同步"

# ========================================
# 捕获环境
# ========================================
log_step "捕获环境依赖..."

# Python
if command -v pip &>/dev/null; then
    pip freeze > "$STATE_DIR/environment/requirements.txt" 2>/dev/null || \
    pip3 freeze > "$STATE_DIR/environment/requirements.txt" 2>/dev/null || true
    log_info "Python 依赖已捕获"
fi

# 系统包
if command -v dpkg &>/dev/null; then
    dpkg --get-selections 2>/dev/null | grep -v deinstall > "$STATE_DIR/environment/apt-packages.txt" || true
    log_info "系统包已捕获"
fi

# Node.js
if command -v npm &>/dev/null; then
    npm ls -g --depth=0 --json 2>/dev/null > "$STATE_DIR/environment/npm-global.json" || true
    if [ -f "$WORKSPACE_DIR/package.json" ]; then
        cp "$WORKSPACE_DIR/package.json" "$STATE_DIR/environment/" 2>/dev/null || true
        [ -f "$WORKSPACE_DIR/package-lock.json" ] && \
            cp "$WORKSPACE_DIR/package-lock.json" "$STATE_DIR/environment/" 2>/dev/null || true
    fi
    log_info "Node.js 依赖已捕获"
fi

# 环境变量
{
    echo "# 环境变量快照"
    echo "# 生成时间: $(date -Iseconds 2>/dev/null || date)"
    for var in PATH PYTHONPATH LANG LC_ALL NODE_PATH HOME SHELL; do
        [ -n "${!var:-}" ] && echo "${var}=${!var}"
    done
} > "$STATE_DIR/environment/env-vars.txt"

# ========================================
# 生成 .gitignore
# ========================================
cat > "$STATE_DIR/.gitignore" << 'EOF'
.env
*.key
*.pem
__pycache__/
node_modules/
.venv/
*.pyc
*.pyo
*.egg-info/
.DS_Store
Thumbs.db
EOF

# ========================================
# 提交并推送
# ========================================
log_step "提交并推送到 GitHub..."
git -C "$STATE_DIR" add -A
git -C "$STATE_DIR" commit -m "init: ${PROJECT_NAME} state initialized" 2>/dev/null || true
git -C "$STATE_DIR" branch -M main

if git -C "$STATE_DIR" push -u origin main 2>/dev/null; then
    log_info "推送成功！"
else
    log_warn "推送失败，尝试增大缓冲..."
    git -C "$STATE_DIR" config http.postBuffer 524288000
    timeout 60 git -C "$STATE_DIR" push -u origin main 2>/dev/null || {
        log_error "推送失败，请检查网络和 PAT 权限"
        log_info "可稍后手动推送: cd $STATE_DIR && git push -u origin main"
    }
fi

# ========================================
# 生成快捷命令
# ========================================
log_step "生成快捷脚本..."

cat > "${STATE_DIR}/resume" << FASTCMD
#!/bin/bash
# openclaw-resume 快捷命令
# 用法: ./resume save|checkpoint|status|sync|env

export OPENCLAW_RESUME_PAT="${PAT}"
export OPENCLAW_RESUME_USER="${GITHUB_USER}"
export OPENCLAW_RESUME_BASE="${RESUME_BASE}"
export OPENCLAW_RESUME_WORKSPACE="${WORKSPACE_DIR}"
export GIT_TERMINAL_PROMPT=0

SCRIPT_DIR="${STATE_DIR}"

case "\${1:-help}" in
    save)
        shift
        MSG="\${*:-manual save}"
        # 同步文件
        if command -v rsync &>/dev/null; then
            rsync -a --delete --exclude='node_modules' --exclude='.git' --exclude='__pycache__' --exclude='.venv' "${WORKSPACE_DIR}/" "\${SCRIPT_DIR}/workspace/" 2>/dev/null
        else
            cp -r "${WORKSPACE_DIR}"/* "\${SCRIPT_DIR}/workspace/" 2>/dev/null || true
        fi
        # 更新进度
        NOW=\$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")
        sed -i "s/last_saved:.*/last_saved: \"\${NOW}\"/" "\${SCRIPT_DIR}/progress.yaml"
        echo "  - \"\$(date +%H:%M) \${MSG}\"" >> "\${SCRIPT_DIR}/progress.yaml"
        # 提交推送
        git -C "\${SCRIPT_DIR}" add -A
        git -C "\${SCRIPT_DIR}" commit -m "save: \${MSG}" 2>/dev/null || echo "无变化"
        git -C "\${SCRIPT_DIR}" push origin main 2>/dev/null && echo "✅ 已保存" || echo "⚠️ 推送失败"
        ;;
    checkpoint)
        shift
        DESC="\${*:-checkpoint}"
        NOW=\$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")
        CP_ID=\$(find "\${SCRIPT_DIR}/checkpoints" -name "*.yaml" 2>/dev/null | wc -l)
        CP_ID=\$((CP_ID + 1))
        cat > "\${SCRIPT_DIR}/checkpoints/\$(printf '%03d' \$CP_ID)-\$(echo "\$DESC" | tr ' ' '-').yaml" << CP_EOF
id: \$CP_ID
timestamp: "\$NOW"
description: "\$DESC"
status: "confirmed"
CP_EOF
        echo "  - \"\$(date +%H:%M) 检查点 #\${CP_ID}: \${DESC}\"" >> "\${SCRIPT_DIR}/progress.yaml"
        git -C "\${SCRIPT_DIR}" add -A
        git -C "\${SCRIPT_DIR}" commit -m "checkpoint: #\${CP_ID} - \${DESC}" 2>/dev/null || true
        git -C "\${SCRIPT_DIR}" push origin main 2>/dev/null && echo "✅ 检查点 #\${CP_ID} 已创建" || echo "⚠️ 推送失败"
        ;;
    status)
        echo ""
        echo "📋 项目: ${PROJECT_NAME}"
        echo "📁 工作目录: ${WORKSPACE_DIR}"
        echo "🔗 GitHub: https://github.com/${GITHUB_USER}/${REPO_NAME}"
        echo ""
        echo "最近操作:"
        grep '^\s*- "' "\${SCRIPT_DIR}/progress.yaml" 2>/dev/null | tail -10
        echo ""
        echo "检查点:"
        ls "\${SCRIPT_DIR}/checkpoints/" 2>/dev/null | head -10 || echo "  无"
        echo ""
        ;;
    sync)
        git -C "\${SCRIPT_DIR}" pull origin main 2>/dev/null && echo "✅ 已同步" || echo "⚠️ 同步失败"
        ;;
    env)
        echo "捕获环境..."
        if command -v pip &>/dev/null; then
            pip freeze > "\${SCRIPT_DIR}/environment/requirements.txt" 2>/dev/null || true
        fi
        if command -v dpkg &>/dev/null; then
            dpkg --get-selections 2>/dev/null | grep -v deinstall > "\${SCRIPT_DIR}/environment/apt-packages.txt" || true
        fi
        git -C "\${SCRIPT_DIR}" add -A
        git -C "\${SCRIPT_DIR}" commit -m "env: 更新环境快照" 2>/dev/null || true
        git -C "\${SCRIPT_DIR}" push origin main 2>/dev/null && echo "✅ 环境已更新" || echo "⚠️ 推送失败"
        ;;
    help|*)
        echo "用法: ./resume <命令>"
        echo ""
        echo "命令:"
        echo "  save [消息]     保存当前状态"
        echo "  checkpoint [描述] 创建检查点"
        echo "  status          查看状态"
        echo "  sync            从 GitHub 拉取"
        echo "  env             更新环境快照"
        ;;
esac
FASTCMD
chmod +x "${STATE_DIR}/resume"

# ========================================
# 完成
# ========================================
echo ""
echo "═══════════════════════════════════════════"
echo ""
log_info "🎉 项目 ${PROJECT_NAME} 初始化完成！"
echo ""
echo "  📁 状态目录: ${STATE_DIR}"
echo "  📂 工作目录: ${WORKSPACE_DIR}"
echo "  🔗 GitHub: https://github.com/${GITHUB_USER}/${REPO_NAME}"
echo ""
echo "  快捷命令（在工作目录下运行）:"
echo "    ${STATE_DIR}/resume save \"保存消息\"    # 保存"
echo "    ${STATE_DIR}/resume checkpoint \"描述\"  # 检查点"
echo "    ${STATE_DIR}/resume status              # 查看状态"
echo "    ${STATE_DIR}/resume sync                # 从 GitHub 拉取"
echo ""
echo "  在 OpenClaw 试用环境恢复:"
echo "    source scripts/resume-restore.sh"
echo "    resume-restore ${PROJECT_NAME}"
echo ""
echo "═══════════════════════════════════════════"
