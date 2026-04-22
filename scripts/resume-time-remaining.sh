#!/bin/bash
# ========================================
# resume-time-remaining: 显示会话剩余时间
# 返回剩余分钟数（整数）
# ========================================

source "$(dirname "$0")/core.sh"

resume-time-remaining() {
    local project_name="${1:-}"

    if [ -z "$project_name" ]; then
        project_name=$(detect_active_project_time)
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
    expires=$(yaml_get progress_file "session.expires_at" "")

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

# 检测活动项目
detect_active_project_time() {
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
    resume-time-remaining "$@"
fi
