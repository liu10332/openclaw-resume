#!/bin/bash
# ========================================
# resume-urgent-save: 紧急保存（时间不足时触发）
# 当剩余时间 < 阈值时自动保存并推送
# ========================================

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

URGENT_THRESHOLD_MIN="${URGENT_THRESHOLD_MIN:-5}"

resume-urgent-save() {
    local project_name="${1:-}"

    if [ -z "$project_name" ]; then
        project_name=$(detect_active_project_urgent)
    fi

    if [ -z "$project_name" ]; then
        log_error "无法检测活动项目"
        return 1
    fi

    local state_dir
    state_dir=$(get_state_dir "$project_name")
    local progress_file="${state_dir}/progress.yaml"

    if [ ! -f "$progress_file" ]; then
        log_error "progress.yaml 不存在"
        return 1
    fi

    # 检查剩余时间
    local remaining
    remaining=$(bash "$(dirname "${BASH_SOURCE[0]}")/resume-time-remaining.sh" "$project_name" 2>/dev/null || echo "0")

    if [ "$remaining" -gt "$URGENT_THRESHOLD_MIN" ] 2>/dev/null; then
        log_info "剩余 ${remaining} 分钟，无需紧急保存"
        return 0
    fi

    log_warn "⚠️  剩余不足 ${URGENT_THRESHOLD_MIN} 分钟！执行紧急保存..."

    # 同步工作文件
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
            "$workspace_src/" "$workspace_dst/" 2>/dev/null || true
    else
        cp -r "$workspace_src"/* "$workspace_dst/" 2>/dev/null || true
    fi

    # 更新进度
    local now
    now=$(now_iso)
    yaml_set "$progress_file" "session.last_saved" "$now"
    add_log_entry "$state_dir" "⚠️ 紧急保存（剩余 ${remaining} 分钟）"

    # 提交推送
    git -C "$state_dir" add -A
    if git -C "$state_dir" diff --cached --quiet; then
        log_info "无变化，跳过"
        return 0
    fi

    git -C "$state_dir" commit -m "urgent-save: 剩余 ${remaining} 分钟"
    if git_push_safe "$state_dir" 5; then
        log_info "✅ 紧急保存完成"
    else
        log_error "紧急保存推送失败！"
        log_info "数据已保存在本地: ${state_dir}"
        return 1
    fi
}

# 检测活动项目
detect_active_project_urgent() {
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

# 如果直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    resume-urgent-save "$@"
fi
