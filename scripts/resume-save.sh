#!/bin/bash
# ========================================
# resume-save: 手动保存当前状态
# ========================================

source "$(dirname "$0")/core.sh"

resume-save() {
    local message="${1:-manual save}"
    local project_name="${2:-}"

    # 自动检测当前活动项目
    if [ -z "$project_name" ]; then
        project_name=$(detect_active_project)
    fi

    if [ -z "$project_name" ]; then
        log_error "无法检测活动项目，请指定: resume-save [message] <project-name>"
        return 1
    fi

    local state_dir
    state_dir=$(get_state_dir "$project_name")
    local progress_file="${state_dir}/progress.yaml"

    if [ ! -f "$progress_file" ]; then
        log_error "progress.yaml 不存在，请先运行 resume-init"
        return 1
    fi

    # 1. 同步工作文件到状态目录
    log_step "同步工作文件..."
    sync_workspace_to_state "$state_dir"

    # 2. 更新 progress.yaml
    log_step "更新进度..."
    local now
    now=$(now_iso)
    yaml_set "$progress_file" "session.last_saved" "$now"
    add_log_entry "$state_dir" "$message"

    # 3. Git 提交推送
    log_step "推送到 GitHub..."
    git -C "$state_dir" add -A
    if git -C "$state_dir" diff --cached --quiet; then
        log_info "没有变化，跳过同步"
        return 0
    fi

    local commit_msg="save: ${message}"
    git -C "$state_dir" commit -m "$commit_msg"

    if git -C "$state_dir" push origin main 2>/dev/null; then
        log_info "✅ 保存成功"
    else
        log_warn "推送失败，尝试 rebase..."
        if git -C "$state_dir" pull --rebase origin main 2>/dev/null && git -C "$state_dir" push origin main 2>/dev/null; then
            log_info "✅ 保存成功（rebase 后）"
        else
            log_error "推送失败，下次自动同步会重试"
            return 1
        fi
    fi
}

# 同步工作目录到状态目录
sync_workspace_to_state() {
    local state_dir="$1"
    local workspace_src="${OPENCLAW_RESUME_WORKSPACE}"
    local workspace_dst="${state_dir}/workspace"

    mkdir -p "$workspace_dst"

    # 使用 rsync 如果可用，否则用 cp
    if command -v rsync &>/dev/null; then
        rsync -a --delete \
            --exclude='node_modules' \
            --exclude='__pycache__' \
            --exclude='.venv' \
            --exclude='.git' \
            --exclude='*.pyc' \
            "$workspace_src/" "$workspace_dst/" 2>/dev/null || true
    else
        # 简单复制（不删除已有文件）
        cp -r "$workspace_src"/* "$workspace_dst/" 2>/dev/null || true
    fi
}

# 检测当前活动项目
detect_active_project() {
    # 从最近修改的 progress.yaml 中检测
    local latest=""
    local latest_time=0

    if [ -d "$OPENCLAW_RESUME_BASE" ]; then
        for dir in "$OPENCLAW_RESUME_BASE"/*/; do
            local progress_file="${dir}progress.yaml"
            if [ -f "$progress_file" ]; then
                local mtime
                mtime=$(stat -c %Y "$progress_file" 2>/dev/null || stat -f %m "$progress_file" 2>/dev/null || echo 0)
                if [ "$mtime" -gt "$latest_time" ]; then
                    latest_time=$mtime
                    latest=$(basename "$dir")
                fi
            fi
        done
    fi

    echo "$latest"
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    resume-save "$@"
fi
