#!/bin/bash
# ========================================
# resume-ask-time: 询问并记录剩余时间
# 用法: source resume-ask-time.sh
#        resume-ask-time <project-name> [remaining-minutes]
# ========================================

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

resume-ask-time() {
    local project_name="${1:-}"
    local remaining="${2:-}"

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

    # 如果没有传入剩余分钟数，交互式询问
    if [ -z "$remaining" ]; then
        echo ""
        echo "⏱️  当前环境还剩多少分钟？（输入整数，如 55）"
        echo "   输入 0 表示不确定，使用默认60分钟"
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

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    resume-ask-time "$@"
fi
