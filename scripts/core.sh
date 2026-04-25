#!/bin/bash
# ========================================
# openclaw-resume 核心脚本
# 提供统一入口函数
# ========================================

set -euo pipefail

# 全局变量
OPENCLAW_RESUME_VERSION="0.2.0"
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
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()    { echo -e "${BLUE}[STEP]${NC} $*"; }
log_debug()   { echo -e "${CYAN}[DEBUG]${NC} $*" >&2; }

# ========================================
# 项目检测（统一实现，消除重复）
# ========================================

# 检测最近活跃的项目（按 progress.yaml 修改时间排序）
detect_active_project() {
    local latest=""
    local latest_time=0

    if [ -d "$OPENCLAW_RESUME_BASE" ]; then
        for dir in "$OPENCLAW_RESUME_BASE"/*/; do
            if [ -d "${dir}.git" ] && [ -f "${dir}progress.yaml" ]; then
                local mtime
                mtime=$(stat -c %Y "${dir}progress.yaml" 2>/dev/null || stat -f %m "${dir}progress.yaml" 2>/dev/null || echo 0)
                if [ "$mtime" -gt "$latest_time" ]; then
                    latest_time=$mtime
                    latest=$(basename "$dir")
                fi
            fi
        done
    fi

    echo "$latest"
    return 0
}

# 列出所有已初始化的项目
list_all_projects() {
    if [ ! -d "$OPENCLAW_RESUME_BASE" ]; then
        return 0
    fi

    for dir in "$OPENCLAW_RESUME_BASE"/*/; do
        if [ -d "${dir}.git" ]; then
            basename "$dir"
        fi
    done
    return 0
}

# 获取项目数量
count_projects() {
    local count=0
    if [ -d "$OPENCLAW_RESUME_BASE" ]; then
        for dir in "$OPENCLAW_RESUME_BASE"/*/; do
            if [ -d "${dir}.git" ]; then
                count=$((count + 1))
            fi
        done
    fi
    echo "$count"
    return 0
}

# ========================================
# 工作区同步（统一实现，消除重复）
# ========================================

# 同步工作目录到状态目录
sync_workspace_to_state() {
    local state_dir="$1"
    local workspace_src="${OPENCLAW_RESUME_WORKSPACE}"
    local workspace_dst="${state_dir}/workspace"

    mkdir -p "$workspace_dst"

    if command -v rsync &>/dev/null; then
        rsync -a --delete \
            --exclude='node_modules' \
            --exclude='__pycache__' \
            --exclude='.venv' \
            --exclude='.git' \
            --exclude='*.pyc' \
            --exclude='*.pyo' \
            --exclude='*.egg-info' \
            --exclude='.DS_Store' \
            "$workspace_src/" "$workspace_dst/" 2>/dev/null || true
    else
        # 简单复制（不删除已有文件）
        cp -r "$workspace_src"/* "$workspace_dst/" 2>/dev/null || true
    fi
}

# ========================================
# 错误处理工具
# ========================================

# 重试包装器：retry <max_attempts> <delay_seconds> <command...>
retry() {
    local max_attempts="$1"
    local delay="$2"
    shift 2
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        fi
        if [ $attempt -lt $max_attempts ]; then
            log_warn "第 ${attempt}/${max_attempts} 次失败，${delay}s 后重试..."
            sleep "$delay"
        fi
        attempt=$((attempt + 1))
    done

    log_error "重试 ${max_attempts} 次后仍然失败: $*"
    return 1
}

# 带重试的 git push
git_push_safe() {
    local state_dir="$1"
    local max_retries="${2:-3}"

    for i in $(seq 1 "$max_retries"); do
        if git -C "$state_dir" push origin main 2>/dev/null; then
            return 0
        fi

        if [ $i -lt "$max_retries" ]; then
            log_warn "push 失败 (${i}/${max_retries})，尝试 pull rebase..."
            git -C "$state_dir" pull --rebase origin main 2>/dev/null || true
            sleep 2
        fi
    done

    log_error "push 失败，已重试 ${max_retries} 次"
    return 1
}

# 带重试的 git pull
git_pull_safe() {
    local state_dir="$1"
    local max_retries="${2:-3}"

    for i in $(seq 1 "$max_retries"); do
        if git -C "$state_dir" pull origin main 2>/dev/null; then
            return 0
        fi

        if [ $i -lt "$max_retries" ]; then
            log_warn "pull 失败 (${i}/${max_retries})，尝试 rebase..."
            git -C "$state_dir" pull --rebase origin main 2>/dev/null && return 0
            sleep 2
        fi
    done

    log_error "pull 失败，已重试 ${max_retries} 次"
    return 1
}

# 验证 GitHub PAT 是否有效
validate_pat() {
    if [ -z "${OPENCLAW_RESUME_PAT:-}" ]; then
        log_error "OPENCLAW_RESUME_PAT 未设置"
        return 1
    fi

    local http_code
    http_code=$(timeout 10 curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token ${OPENCLAW_RESUME_PAT}" \
        "https://api.github.com/user" 2>/dev/null || echo "000")

    case "$http_code" in
        200) return 0 ;;
        401) log_error "PAT 无效或已过期"; return 1 ;;
        403) log_error "PAT 权限不足"; return 1 ;;
        000) log_warn "无法连接 GitHub API（网络问题）"; return 0 ;;  # 网络问题不阻断
        *)   log_warn "GitHub API 返回 ${http_code}"; return 0 ;;
    esac
}

# 验证 GitHub 仓库是否存在
validate_repo() {
    local repo_url="$1"
    local http_code
    http_code=$(timeout 10 curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token ${OPENCLAW_RESUME_PAT}" \
        "$repo_url" 2>/dev/null || echo "000")

    case "$http_code" in
        200) return 0 ;;
        404) return 1 ;;
        *)   return 0 ;;  # 其他情况不阻断
    esac
}

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
# 用法: yaml_get <file> <dotted.key> [default]
# 示例: yaml_get progress.yaml "session.id" ""
yaml_get() {
    local file="$1"
    local key="$2"
    local default="${3:-}"

    if has_yq; then
        yq -r ".${key} // \"${default}\"" "$file" 2>/dev/null || echo "$default"
    else
        # 无 yq 时的兼容方案：按缩进层级匹配
        # 将 "session.id" 拆分为父级 "session" 和字段 "id"
        local parent="${key%%.*}"
        local field="${key##*.}"

        if [ "$parent" = "$field" ]; then
            # 单层 key，直接匹配顶层
            local value
            value=$(grep -E "^${field}:" "$file" 2>/dev/null | head -1 | sed 's/^[^:]*: *//; s/^"//; s/"$//; s/^'\''//; s/'\''$//' || true)
        else
            # 双层 key：先定位父级块，再在块内匹配字段
            # 使用 awk 提取父级 section 下的字段
            local value
            value=$(awk -v parent="$parent" -v field="$field" '
                BEGIN { in_section=0 }
                $0 ~ "^"parent":" { in_section=1; next }
                in_section && /^[^ ]/ { in_section=0 }
                in_section && $0 ~ "^  "field":" {
                    sub(/^  [^:]*: */, "")
                    gsub(/^["'\''"]|["'\''"]$/, "")
                    print
                    exit
                }
            ' "$file" 2>/dev/null || true)
        fi
        echo "${value:-$default}"
    fi
}

# 写入 YAML 字段（兼容无 yq 或低版本 yq）
# 用法: yaml_set <file> <dotted.key> <value>
yaml_set() {
    local file="$1"
    local key="$2"
    local value="$3"

    # 先尝试 yq，失败则使用 sed
    if has_yq && yq -i ".${key} = \"${value}\"" "$file" 2>/dev/null; then
        return 0
    fi

    # 兼容性方案：按缩进层级定位并替换
    local parent="${key%%.*}"
    local field="${key##*.}"

    if [ "$parent" = "$field" ]; then
        # 单层 key：直接替换顶层字段
        sed -i "s/^\(${field}:\).*/\1 \"${value}\"/" "$file"
    else
        # 双层 key：定位父级块后替换字段
        # 使用 awk + sed 组合：先找到字段所在行号，再替换
        local line_num
        line_num=$(awk -v parent="$parent" -v field="$field" '
            BEGIN { in_section=0 }
            $0 ~ "^"parent":" { in_section=1; next }
            in_section && /^[^ ]/ { in_section=0 }
            in_section && $0 ~ "^  "field":" { print NR; exit }
        ' "$file" 2>/dev/null || true)

        if [ -n "$line_num" ]; then
            sed -i "${line_num}s/^\(  ${field}:\).*/\1 \"${value}\"/" "$file"
        fi
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

# ========================================
# 版本信息（不自动打印，通过 --version 触发）
# ========================================
show_version() {
    echo "openclaw-resume v${OPENCLAW_RESUME_VERSION}"
}
