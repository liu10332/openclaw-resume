#!/bin/bash
# ========================================
# resume-ask-time: 询问并记录剩余时间
# 用法: source resume-ask-time.sh
#        resume-ask-time <project-name>
# ========================================

source "$(dirname "$0")/core.sh"

resume-ask-time() {
    local project_name="${1:-}"

    if [ -z "$project_name" ]; then
        project_name=$(detect_active_project_ask)
    fi

    if [ -z "$project_name" ]; then
        log_error "无法检测活动项目"
        return 1
    fi

    local state_dir
    state_dir=$(get_state_dir "$project_name")
    local progress_file="${state_dir}/progress.yaml"

    echo ""
    echo "⏱️  当前环境还剩多少分钟？（输入整数，如 55）"
    echo "   输入 0 表示不确定，使用默认60分钟"

    # 读取用户输入（从 stdin 或参数）
    local remaining="${2:-}"

    if [ -z "$remaining" ]; then
        echo -n "剩余分钟数: "
        read -r remaining
    fi

    # 验证输入
    if ! [[ "$remaining" =~ ^[0-9]+$ ]]; then
        log_warn "输入无效，使用默认60分钟"
        remaining=60
    fi

    if [ "$remaining" -eq 0 ]; then
        remaining=60
    fi

    # 计算 expires_at
    local expires
    expires=$(date -d "+${remaining} minutes" -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")

    # 更新 progress.yaml
    yaml_set "$progress_file" "session.expires_at" "$expires"

    log_info "✅ 已设置 ${remaining} 分钟后到期"
    log_info "   过期时间: ${expires}"
    echo ""

    # 返回剩余分钟数
    echo "$remaining"
}

# 检测活动项目
detect_active_project_ask() {
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
    resume-ask-time "$@"
fi
