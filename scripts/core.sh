#!/bin/bash
# ========================================
# openclaw-resume 核心脚本
# 提供统一入口函数
# ========================================

set -euo pipefail

# 全局变量
OPENCLAW_RESUME_VERSION="0.1.0"
OPENCLAW_RESUME_BASE="${OPENCLAW_RESUME_BASE:-$HOME/.openclaw-resume}"
OPENCLAW_RESUME_WORKSPACE="${OPENCLAW_RESUME_WORKSPACE:-$HOME/workspace}"

# 禁止 git 交互式提示（避免卡住）
export GIT_TERMINAL_PROMPT=0
# 增大 HTTP 缓冲（避免大 push 超时）
git config --global http.postBuffer 524288000 2>/dev/null || true

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()    { echo -e "${BLUE}[STEP]${NC} $*"; }

# 检查前置条件
check_prerequisites() {
    local missing=0

    if [ -z "${OPENCLAW_RESUME_PAT:-}" ]; then
        log_error "OPENCLAW_RESUME_PAT 未设置"
        log_info "请运行: export OPENCLAW_RESUME_PAT='ghp_xxxxxxxxxxxx'"
        missing=1
    fi

    if [ -z "${OPENCLAW_RESUME_USER:-}" ]; then
        log_error "OPENCLAW_RESUME_USER 未设置"
        log_info "请运行: export OPENCLAW_RESUME_USER='your-github-username'"
        missing=1
    fi

    if ! command -v git &>/dev/null; then
        log_error "git 未安装"
        missing=1
    fi

    if ! command -v yq &>/dev/null; then
        log_warn "yq 未安装，将使用 sed/grep 处理 YAML（功能受限）"
        log_info "建议安装: pip install yq  或  apt install yq"
    fi

    return $missing
}

# 获取项目状态目录
get_state_dir() {
    local project_name="$1"
    echo "${OPENCLAW_RESUME_BASE}/${project_name}"
}

# 生成会话 ID
generate_session_id() {
    local hour
    hour=$(date +%H)
    local period="am"
    if [ "$hour" -ge 12 ]; then
        period="pm"
    fi

    # 查找今天已有多少个会话
    local today
    today=$(date +%Y-%m-%d)
    local count=1
    local project_name="${1:-}"
    local state_dir="${OPENCLAW_RESUME_BASE}/${project_name}"

    if [ -n "$project_name" ] && [ -d "$state_dir/.git" ]; then
        # 从 git 历史查找今天的会话数（使用 git -C 避免路径依赖）
        count=$(git -C "$state_dir" log --oneline --after="${today}T00:00:00" --grep="session_start" 2>/dev/null | wc -l)
        count=$((count + 1))
    fi

    echo "${today}-${period}-${count}"
}

# 获取当前时间 ISO 8601
now_iso() {
    date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z"
}

# 计算过期时间（开始后1小时）
calc_expires_at() {
    date -d "+1 hour" -Iseconds 2>/dev/null || date -v+1H +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null || echo "unknown"
}

# 检查 yq 是否可用
has_yq() {
    command -v yq &>/dev/null
}

# 读取 YAML 字段（兼容无 yq）
yaml_get() {
    local file="$1"
    local key="$2"
    local default="${3:-}"

    if has_yq; then
        yq -r ".${key} // \"${default}\"" "$file" 2>/dev/null || echo "$default"
    else
        # 简单 grep 匹配（仅支持顶层和二级字段）
        local value
        value=$(grep -E "^  ${key##*.}:" "$file" 2>/dev/null | head -1 | sed 's/^[^:]*: *//; s/^"//; s/"$//' || true)
        echo "${value:-$default}"
    fi
}

# 写入 YAML 字段（兼容无 yq 或低版本 yq）
yaml_set() {
    local file="$1"
    local key="$2"
    local value="$3"

    # 先尝试直接写，失败则使用临时文件覆盖
    if has_yq && yq -i ".${key} = \"${value}\"" "$file" 2>/dev/null; then
        return 0
    else
        # 兼容性方案：提取字段名，用 sed 替换
        local field_name="${key##*.}"
        # 仅替换二级字段，格式为 '  key: "value"'
        sed -i "s/^\(  ${field_name}:\).*/\1 \"${value}\"/" "$file"
    fi
}

# 追加 log 条目（一行文本）
add_log_entry() {
    local state_dir="$1"
    local entry_text="$2"

    local progress_file="${state_dir}/progress.yaml"
    local time_str
    time_str=$(date +%H:%M)

    local entry="  - \"${time_str} ${entry_text}\""

    # 找到 log: 行，在其后插入条目
    if grep -q "^log: \[\]" "$progress_file" 2>/dev/null; then
        # log: [] → 替换为 log: + 条目
        sed -i "s|^log: \[\]|log:\n${entry}|" "$progress_file"
    elif grep -q "^log:" "$progress_file" 2>/dev/null; then
        # log: 已有内容，在 log: 行后插入条目
        sed -i "/^log:/a\\${entry}" "$progress_file"
    else
        # 没有 log 段落，追加到末尾
        {
            echo "log:"
            echo "$entry"
        } >> "$progress_file"
    fi
}

# 检查是否有待处理的 log（.pending_log 文件）
check_pending_log() {
    local state_dir="$1"
    local pending_file="${state_dir}/.pending_log"

    if [ -f "$pending_file" ]; then
        cat "$pending_file"
        rm "$pending_file"
        return 0
    fi
    return 1
}

# 创建待处理 log 标记
create_pending_log() {
    local state_dir="$1"
    local summary="$2"
    local pending_file="${state_dir}/.pending_log"

    echo "$summary" > "$pending_file"
}

# 获取当前时间 HH:MM
current_time_hm() {
    date +%H:%M
}

echo "openclaw-resume v${OPENCLAW_RESUME_VERSION} loaded"
