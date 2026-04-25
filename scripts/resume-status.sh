#!/bin/bash
# ========================================
# resume-status: 查看当前状态
# ========================================

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

resume-status() {
    local project_name="${1:-}"

    if [ -z "$project_name" ]; then
        project_name=$(detect_active_project)
    fi

    if [ -z "$project_name" ]; then
        log_error "未找到已初始化的项目"
        log_info "请运行: resume-init <project-name>"
        return 1
    fi

    local state_dir
    state_dir=$(get_state_dir "$project_name")
    local progress_file="${state_dir}/progress.yaml"

    if [ ! -f "$progress_file" ]; then
        log_error "progress.yaml 不存在"
        return 1
    fi

    # 读取所有关键字段
    local session_id project task step total note
    local started expires saved

    session_id=$(yaml_get "$progress_file" "session.id" "")
    started=$(yaml_get "$progress_file" "session.started" "")
    expires=$(yaml_get "$progress_file" "session.expires_at" "")
    saved=$(yaml_get "$progress_file" "session.last_saved" "")

    project=$(yaml_get "$progress_file" "position.project" "")
    task=$(yaml_get "$progress_file" "position.task" "")
    step=$(yaml_get "$progress_file" "position.step" "0")
    total=$(yaml_get "$progress_file" "position.total_steps" "0")
    note=$(yaml_get "$progress_file" "position.note" "")

    # 计算剩余时间
    local remaining=""
    if [ -n "$expires" ] && [ "$expires" != "unknown" ]; then
        local expire_epoch now_epoch
        expire_epoch=$(date -d "$expires" +%s 2>/dev/null || echo 0)
        now_epoch=$(date +%s)
        if [ "$expire_epoch" -gt "$now_epoch" ]; then
            local diff=$((expire_epoch - now_epoch))
            local mins=$((diff / 60))
            remaining="${mins} 分钟"
        else
            remaining="已过期"
        fi
    fi

    # 检查定时器状态
    local timer_info="未运行"
    if [ -f "/tmp/openclaw-resume-sync.pid" ] && kill -0 "$(cat "/tmp/openclaw-resume-sync.pid")" 2>/dev/null; then
        timer_info="运行中 ✓"
    fi

    # 检查点统计
    local checkpoints_dir="${state_dir}/checkpoints"
    local total_cp=0 confirmed_cp=0 pending_cp=0
    if [ -d "$checkpoints_dir" ]; then
        total_cp=$(find "$checkpoints_dir" -name "*.yaml" 2>/dev/null | wc -l)
        confirmed_cp=$(grep -rl 'status: "confirmed"' "$checkpoints_dir" 2>/dev/null | wc -l)
        pending_cp=$((total_cp - confirmed_cp))
    fi

    # 输出状态
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║         openclaw-resume 状态面板              ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    echo "  📦 项目: ${project}"
    echo "  🆔 会话: ${session_id}"
    echo ""
    echo "  ┌─ 时间 ─────────────────────────────────────┐"
    echo "  │ 开始: ${started}"
    echo "  │ 过期: ${expires}"
    echo "  │ 剩余: ${remaining}"
    echo "  │ 最后保存: ${saved}"
    echo "  │ 定时器: ${timer_info}"
    echo "  └────────────────────────────────────────────┘"
    echo ""
    echo "  ┌─ 当前进度 ─────────────────────────────────┐"
    echo "  │ 任务: ${task}"
    echo "  │ 进度: ${step}/${total}"
    echo "  │ 备注: ${note}"
    echo "  └────────────────────────────────────────────┘"
    echo ""
    echo "  ┌─ 检查点 ───────────────────────────────────┐"
    echo "  │ 总计: ${total_cp} | 已确认: ${confirmed_cp} | 待确认: ${pending_cp}"
    echo "  └────────────────────────────────────────────┘"
    echo ""

    # 最近的 log
    echo "  📜 最近操作:"
    grep -E "^\s+- \"" "$progress_file" 2>/dev/null | tail -10 | while read -r line; do
        echo "    $line"
    done
    echo ""
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    resume-status "$@"
fi
