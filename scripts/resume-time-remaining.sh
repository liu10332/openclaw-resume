#!/bin/bash
# ========================================
# resume-time-remaining: 显示会话剩余时间
# 返回剩余分钟数（整数）
# ========================================

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

resume-time-remaining() {
    local project_name="${1:-}"

    if [ -z "$project_name" ]; then
        project_name=$(detect_active_project)
    fi

    if [ -z "$project_name" ]; then
        echo "0"
        return 1
    fi

    local state_dir
    state_dir=$(get_state_dir "$project_name")
    local progress_file="${state_dir}/progress.yaml"

    if [ ! -f "$progress_file" ]; then
        echo "0"
        return 1
    fi

    # 读取 expires_at
    local expires
    expires=$(yaml_get "$progress_file" "session.expires_at" "")

    if [ -z "$expires" ] || [ "$expires" = "unknown" ]; then
        echo "0"
        return 1
    fi

    # 计算剩余时间
    local expire_epoch now_epoch diff mins
    expire_epoch=$(date -d "$expires" +%s 2>/dev/null || echo 0)
    now_epoch=$(date +%s)

    if [ "$expire_epoch" -le "$now_epoch" ]; then
        echo "0"
        return 0
    fi

    diff=$((expire_epoch - now_epoch))
    mins=$((diff / 60))

    echo "$mins"
    return 0
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    resume-time-remaining "$@"
fi
