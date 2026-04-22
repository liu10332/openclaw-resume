#!/bin/bash
# ========================================
# resume-timer: 自动同步定时器管理
# ========================================

source "$(dirname "$0")/core.sh"

SYNC_INTERVAL=900  # 15分钟
PID_FILE="/tmp/openclaw-resume-sync.pid"
LOG_FILE="/tmp/openclaw-resume-sync.log"

resume-timer() {
    local action="${1:-status}"
    local project_name="${2:-}"

    case "$action" in
        start)
            if [ -z "$project_name" ]; then
                project_name=$(detect_active_project_timer)
            fi
            start_timer "$project_name"
            ;;
        stop)
            stop_timer
            ;;
        status)
            timer_status
            ;;
        *)
            log_error "用法: resume-timer <start|stop|status> [project-name]"
            return 1
            ;;
    esac
}

start_timer() {
    local project_name="$1"

    if [ -z "$project_name" ]; then
        log_error "无法检测活动项目，请指定: resume-timer start <project-name>"
        return 1
    fi

    # 检查是否已在运行
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        log_warn "定时器已在运行 (PID: $(cat "$PID_FILE"))"
        return 0
    fi

    local state_dir
    state_dir=$(get_state_dir "$project_name")

    log_info "启动自动同步定时器（每 $((SYNC_INTERVAL / 60)) 分钟）..."
    log_info "项目: ${project_name}"
    log_info "状态目录: ${state_dir}"

    # 后台运行同步循环
    (
        while true; do
            sleep "$SYNC_INTERVAL"

            # 检查父进程是否还在
            if [ ! -f "$PID_FILE" ]; then
                break
            fi

            # 执行同步
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 执行自动同步..." >> "$LOG_FILE"

            # 更新 last_saved
            local now
            now=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")
            sed -i "s/last_saved:.*/last_saved: \"${now}\"/" "${state_dir}/progress.yaml" 2>/dev/null || true

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

            # Git 操作，使用 git -C 避免路径依赖
            git -C "$state_dir" add -A
            if ! git -C "$state_dir" diff --cached --quiet; then
                # 有变化，创建 pending_log 标记
                local diff_summary
                diff_summary=$(git -C "$state_dir" diff --cached --stat | tail -1)
                echo "[$(date '+%Y-%m-%d %H:%M')] 文件变化: $diff_summary" > "${state_dir}/.pending_log"

                git -C "$state_dir" commit -m "auto-sync: $(date '+%Y-%m-%d %H:%M')" >> "$LOG_FILE" 2>&1
                if git -C "$state_dir" push origin main >> "$LOG_FILE" 2>&1; then
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 同步成功（有变化）" >> "$LOG_FILE"
                else
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 同步失败，将在下次重试" >> "$LOG_FILE"
                    # 尝试 pull rebase
                    git -C "$state_dir" pull --rebase origin main >> "$LOG_FILE" 2>&1 || true
                fi
            else
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] 无变化，跳过" >> "$LOG_FILE"
            fi
        done
    ) &

    echo $! > "$PID_FILE"
    log_info "✅ 定时器已启动 (PID: $!)"
    log_info "   日志: ${LOG_FILE}"
    log_info "   停止: resume-timer stop"
}

stop_timer() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            rm "$PID_FILE"
            log_info "✅ 定时器已停止"

            # 最后一次同步
            log_info "执行最后一次同步..."
            local project_name
            project_name=$(detect_active_project_timer)
            if [ -n "$project_name" ]; then
                bash "$(dirname "$0")/resume-save.sh" "timer_stopped: final sync" "$project_name"
            fi
        else
            rm "$PID_FILE"
            log_warn "定时器进程已不存在，清理 PID 文件"
        fi
    else
        log_info "定时器未运行"
    fi
}

timer_status() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "定时器运行中 (PID: ${pid})"

            # 显示最近的同步日志
            if [ -f "$LOG_FILE" ]; then
                echo ""
                echo "最近同步记录:"
                tail -5 "$LOG_FILE"
            fi
        else
            log_warn "定时器 PID 文件存在但进程已死，清理中..."
            rm "$PID_FILE"
        fi
    else
        log_info "定时器未运行"
    fi
}

# 检测活动项目
detect_active_project_timer() {
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
    resume-timer "$@"
fi
