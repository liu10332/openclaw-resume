#!/bin/bash
# ========================================
# resume-list: 列出所有项目及状态
# ========================================

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

resume-list() {
    local show_all="${1:-}"

    if [ ! -d "$OPENCLAW_RESUME_BASE" ]; then
        log_info "还没有初始化任何项目"
        log_info "运行 resume-init <project-name> 开始"
        return 0
    fi

    local projects=()
    while IFS= read -r line; do
        [ -n "$line" ] && projects+=("$line")
    done < <(list_all_projects)

    if [ ${#projects[@]} -eq 0 ]; then
        log_info "还没有初始化任何项目"
        log_info "运行 resume-init <project-name> 开始"
        return 0
    fi

    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║                       openclaw-resume 项目列表                       ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""

    # 表头
    printf "  ${CYAN}%-20s %-14s %-20s %-10s %-8s${NC}\n" \
        "项目名" "最后保存" "当前任务" "检查点" "定时器"
    printf "  %-20s %-14s %-20s %-10s %-8s\n" \
        "────────────────────" "──────────────" "────────────────────" "──────────" "────────"

    for project in "${projects[@]}"; do
        local state_dir
        state_dir=$(get_state_dir "$project")
        local progress_file="${state_dir}/progress.yaml"

        # 最后保存时间（取 HH:MM 部分）
        local last_saved="—"
        local task="—"
        local cp_count="0"
        local timer_status="✗"

        if [ -f "$progress_file" ]; then
            local raw_saved
            raw_saved=$(yaml_get "$progress_file" "session.last_saved" "")
            if [ -n "$raw_saved" ]; then
                # 提取时间部分 HH:MM 或日期
                last_saved=$(echo "$raw_saved" | grep -oP '\d{2}:\d{2}' | head -1 || echo "$raw_saved")
            fi

            task=$(yaml_get "$progress_file" "position.task" "")
            [ -z "$task" ] && task="—"

            # 截断过长的任务描述
            if [ ${#task} -gt 18 ]; then
                task="${task:0:16}.."
            fi

            # 检查点数量
            if [ -d "${state_dir}/checkpoints" ]; then
                cp_count=$(find "${state_dir}/checkpoints" -name "*.yaml" 2>/dev/null | wc -l)
            fi
        fi

        # 定时器状态
        if [ -f "/tmp/openclaw-resume-sync.pid" ] && kill -0 "$(cat "/tmp/openclaw-resume-sync.pid")" 2>/dev/null; then
            timer_status="✓"
        fi

        # git 状态
        local git_status=""
        if [ -d "${state_dir}/.git" ]; then
            local behind
            behind=$(git -C "$state_dir" rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
            if [ "$behind" -gt 0 ] 2>/dev/null; then
                git_status=" ⚠️"
            fi
        fi

        printf "  %-20s %-14s %-20s %-10s %-8s%s\n" \
            "$project" "$last_saved" "$task" "$cp_count" "$timer_status" "$git_status"
    done

    echo ""

    # 统计
    local total=${#projects[@]}
    local active=0
    if [ -f "/tmp/openclaw-resume-sync.pid" ] && kill -0 "$(cat "/tmp/openclaw-resume-sync.pid")" 2>/dev/null; then
        active=1
    fi

    echo "  共 ${total} 个项目 | ${active} 个定时器运行中"
    echo ""

    # 详细模式
    if [ "$show_all" = "--all" ] || [ "$show_all" = "-a" ]; then
        echo "  ────────────────────────────────────────────"
        echo "  详细信息 (--all):"
        echo ""
        for project in "${projects[@]}"; do
            local state_dir
            state_dir=$(get_state_dir "$project")
            local progress_file="${state_dir}/progress.yaml"

            echo "  📁 ${project}"
            echo "     路径: ${state_dir}"
            if [ -f "$progress_file" ]; then
                local session_id
                session_id=$(yaml_get "$progress_file" "session.id" "—")
                local note
                note=$(yaml_get "$progress_file" "position.note" "")
                echo "     会话: ${session_id}"
                [ -n "$note" ] && echo "     备注: ${note}"
            fi

            # 最近 log
            if [ -f "$progress_file" ]; then
                local last_log
                last_log=$(grep -E '^\s+- "' "$progress_file" 2>/dev/null | tail -1)
                [ -n "$last_log" ] && echo "     最近: ${last_log}"
            fi
            echo ""
        done
    fi
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    resume-list "$@"
fi
