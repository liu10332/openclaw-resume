#!/bin/bash
# ========================================
# resume-restore: 从 GitHub 恢复上次状态
# ========================================

source "$(dirname "$0")/core.sh"

resume-restore() {
    local project_name="${1:-}"

    if [ -z "$project_name" ]; then
        # 尝试自动检测：扫描已有项目
        log_info "未指定项目名，扫描已有项目..."
        if [ -d "$OPENCLAW_RESUME_BASE" ]; then
            local projects=()
            for dir in "$OPENCLAW_RESUME_BASE"/*/; do
                [ -d "$dir/.git" ] && projects+=("$(basename "$dir")")
            done

            if [ ${#projects[@]} -eq 0 ]; then
                log_error "未找到已初始化的项目，请运行: resume-init <project-name>"
                return 1
            elif [ ${#projects[@]} -eq 1 ]; then
                project_name="${projects[0]}"
                log_info "自动选择: ${project_name}"
            else
                log_info "找到多个项目:"
                for i in "${!projects[@]}"; do
                    echo "  $((i+1)). ${projects[$i]}"
                done
                echo -n "选择: "
                read -r choice
                project_name="${projects[$((choice-1))]}"
            fi
        else
            log_error "未找到项目，请运行: resume-init <project-name>"
            return 1
        fi
    fi

    # 1. 检查前置条件
    check_prerequisites || return 1

    local state_dir
    state_dir=$(get_state_dir "$project_name")

    # 2. 拉取最新状态
    log_step "从 GitHub 拉取最新状态..."
    if [ -d "$state_dir/.git" ]; then
        git -C "$state_dir" pull origin main 2>/dev/null || {
            log_warn "拉取失败，尝试 rebase..."
            git -C "$state_dir" pull --rebase origin main 2>/dev/null || log_warn "拉取失败，使用本地版本"
        }
    else
        log_error "本地状态目录不存在，请先运行: resume-init ${project_name}"
        return 1
    fi

    # 3. 读取并显示上次进度
    log_step "读取上次进度..."
    local progress_file="${state_dir}/progress.yaml"

    if [ ! -f "$progress_file" ]; then
        log_error "progress.yaml 不存在"
        return 1
    fi

    local last_project last_task last_step last_note
    last_project=$(yaml_get progress_file "position.project" "")
    last_task=$(yaml_get progress_file "position.task" "")
    last_step=$(yaml_get progress_file "position.step" "0")
    last_note=$(yaml_get progress_file "position.note" "")

    echo ""
    echo "═══════════════════════════════════════════"
    echo "  📋 上次进度"
    echo "═══════════════════════════════════════════"
    echo "  项目: ${last_project}"
    echo "  任务: ${last_task}"
    echo "  步骤: ${last_step}"
    echo "  备注: ${last_note}"
    echo "═══════════════════════════════════════════"
    echo ""

    # 4. 恢复工作文件
    log_step "恢复工作文件..."
    local workspace_dir="${state_dir}/workspace"
    if [ -d "$workspace_dir" ] && [ "$(ls -A "$workspace_dir" 2>/dev/null)" ]; then
        # 确保目标目录存在
        mkdir -p "$OPENCLAW_RESUME_WORKSPACE"
        cp -r "$workspace_dir"/* "$OPENCLAW_RESUME_WORKSPACE/" 2>/dev/null || true
        log_info "工作文件已恢复到 ${OPENCLAW_RESUME_WORKSPACE}/"
    else
        log_info "无工作文件需要恢复"
    fi

    # 5. 恢复环境
    log_step "恢复环境依赖..."
    local setup_script="${state_dir}/environment/setup.sh"
    if [ -f "$setup_script" ]; then
        log_info "执行环境恢复脚本..."
        bash "$setup_script" 2>/dev/null || log_warn "环境恢复部分失败，请手动检查"
    else
        log_info "无环境恢复脚本，跳过"
    fi

    # 6. 更新会话信息
    log_step "更新会话信息..."
    local session_id
    session_id=$(generate_session_id "$project_name")
    local now
    now=$(now_iso)
    local expires
    expires=$(calc_expires_at)

    yaml_set progress_file "session.id" "$session_id"
    yaml_set progress_file "session.started" "$now"
    yaml_set progress_file "session.expires_at" "$expires"
    yaml_set progress_file "session.last_saved" "$now"

    add_log_entry "$state_dir" "从检查点恢复，继续工作"

    # 7. 检查并处理 .pending_log
    log_step "检查未处理的 log..."
    local pending_log="${state_dir}/.pending_log"
    if [ -f "$pending_log" ]; then
        local pending_content
        pending_content=$(cat "$pending_log")
        log_info "发现上次会话未处理的变化: $pending_content"
        add_log_entry "$state_dir" "上次遗留: $pending_content"
        rm "$pending_log"
    fi

    # 8. 提交会话开始
    git -C "$state_dir" add -A
    git -C "$state_dir" commit -m "restore: session ${session_id} started" 2>/dev/null || true
    git -C "$state_dir" push origin main 2>/dev/null || log_warn "推送失败，稍后自动同步会重试"

    # 8. 启动定时器
    log_step "启动自动同步定时器..."
    bash "$(dirname "$0")/resume-timer.sh" start "$project_name"

    log_info "✅ 恢复完成，继续上次的工作吧"

    # 9. 询问剩余时间
    log_step "设置环境剩余时间..."
    bash "$(dirname "$0")/resume-ask-time.sh" "$project_name" ""
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    resume-restore "$@"
fi
