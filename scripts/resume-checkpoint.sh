#!/bin/bash
# ========================================
# resume-checkpoint: 创建检查点
# ========================================

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

resume-checkpoint() {
    local description="${1:-}"
    local project_name="${2:-}"

    if [ -z "$description" ]; then
        log_error "用法: resume-checkpoint <description> [project-name]"
        return 1
    fi

    if [ -z "$project_name" ]; then
        project_name=$(detect_active_project)
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

    # 1. 生成检查点 ID
    local checkpoint_id
    checkpoint_id=$(get_next_checkpoint_id "$state_dir")

    # 2. 创建检查点文件
    local checkpoint_file="${state_dir}/checkpoints/$(printf '%03d' "$checkpoint_id")-$(echo "$description" | tr ' ' '-' | tr -cd 'a-zA-Z0-9-' | cut -c1-50).yaml"

    cat > "$checkpoint_file" << EOF
# 检查点 #${checkpoint_id}
id: ${checkpoint_id}
timestamp: "$(now_iso)"
description: "${description}"
status: "pending_confirmation"
project: "${project_name}"

# 当前进度快照
position_snapshot:
$(head -20 "$progress_file" | grep -A 10 "position:" || echo "  unavailable: true")

# 文件变化
files_changed: []

# Git 信息
git_commit: "$(git -C "$state_dir" rev-parse --short HEAD 2>/dev/null || echo 'none')"
EOF

    # 3. 追加到 progress.yaml 的 checkpoints 列表
    add_log_entry "$state_dir" "创建检查点 #${checkpoint_id}: ${description}"

    # 4. 同步工作文件（使用 core.sh 统一函数）
    sync_workspace_to_state "$state_dir"

    # 5. 提交推送
    git -C "$state_dir" add -A
    git -C "$state_dir" commit -m "checkpoint: #${checkpoint_id} - ${description}"
    git -C "$state_dir" push origin main 2>/dev/null || log_warn "推送失败，稍后自动同步会重试"

    log_info "✅ 检查点 #${checkpoint_id} 已创建: ${description}"
    log_info "   状态: pending_confirmation"
    log_info "   确认后将变为 confirmed"
}

# 确认检查点
resume-checkpoint-confirm() {
    local checkpoint_id="${1:-}"
    local project_name="${2:-}"

    if [ -z "$checkpoint_id" ]; then
        log_error "用法: resume-checkpoint-confirm <checkpoint-id> [project-name]"
        return 1
    fi

    if [ -z "$project_name" ]; then
        project_name=$(detect_active_project)
    fi

    local state_dir
    state_dir=$(get_state_dir "$project_name")

    # 查找检查点文件
    local checkpoint_file
    checkpoint_file=$(find "$state_dir/checkpoints/" -name "$(printf '%03d' "$checkpoint_id")-*" 2>/dev/null | head -1)

    if [ -z "$checkpoint_file" ]; then
        log_error "检查点 #${checkpoint_id} 不存在"
        return 1
    fi

    # 更新状态
    sed -i 's/status: "pending_confirmation"/status: "confirmed"/' "$checkpoint_file"

    git -C "$state_dir" add -A
    git -C "$state_dir" commit -m "confirm: checkpoint #${checkpoint_id}"
    git -C "$state_dir" push origin main 2>/dev/null || true

    log_info "✅ 检查点 #${checkpoint_id} 已确认"
}

# 获取下一个检查点 ID
get_next_checkpoint_id() {
    local state_dir="$1"
    local checkpoints_dir="${state_dir}/checkpoints"
    mkdir -p "$checkpoints_dir"

    local count
    count=$(find "$checkpoints_dir" -name "*.yaml" 2>/dev/null | wc -l)
    echo $((count + 1))
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        confirm)
            shift
            resume-checkpoint-confirm "$@"
            ;;
        *)
            resume-checkpoint "$@"
            ;;
    esac
fi
