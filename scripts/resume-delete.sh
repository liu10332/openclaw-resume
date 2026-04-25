#!/bin/bash
# ========================================
# resume-delete: 删除项目（本地 + 可选 GitHub）
# ========================================

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

resume-delete() {
    local project_name="${1:-}"
    local force="${2:-}"

    if [ -z "$project_name" ]; then
        log_error "用法: resume-delete <project-name> [--force]"
        echo ""
        echo "  删除指定项目的本地状态和（可选）GitHub 仓库"
        echo ""
        echo "  选项:"
        echo "    --force    跳过确认提示"
        echo ""
        echo "  示例:"
        echo "    resume-delete my-project"
        echo "    resume-delete my-project --force"
        return 1
    fi

    local state_dir
    state_dir=$(get_state_dir "$project_name")

    # 检查项目是否存在
    if [ ! -d "$state_dir" ]; then
        log_error "项目 ${project_name} 不存在"
        log_info "运行 resume-list 查看所有项目"
        return 1
    fi

    # 显示项目信息
    echo ""
    echo "  ⚠️  即将删除项目: ${project_name}"
    echo ""

    local progress_file="${state_dir}/progress.yaml"
    if [ -f "$progress_file" ]; then
        local task
        task=$(yaml_get "$progress_file" "position.task" "—")
        local last_saved
        last_saved=$(yaml_get "$progress_file" "session.last_saved" "—")
        local cp_count=0
        if [ -d "${state_dir}/checkpoints" ]; then
            cp_count=$(find "${state_dir}/checkpoints" -name "*.yaml" 2>/dev/null | wc -l)
        fi

        echo "     任务: ${task}"
        echo "     最后保存: ${last_saved}"
        echo "     检查点: ${cp_count} 个"
    fi

    # 文件统计
    local file_count=0
    if [ -d "${state_dir}/workspace" ]; then
        file_count=$(find "${state_dir}/workspace" -type f 2>/dev/null | wc -l)
    fi
    echo "     工作文件: ${file_count} 个"
    echo "     本地路径: ${state_dir}"
    echo ""

    # 检查 GitHub 仓库是否存在
    local repo_name="${project_name}-state"
    local github_user="${OPENCLAW_RESUME_USER:-}"
    local has_github_repo=false

    if [ -n "$github_user" ] && [ -n "${OPENCLAW_RESUME_PAT:-}" ]; then
        local http_code
        http_code=$(timeout 5 curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: token ${OPENCLAW_RESUME_PAT}" \
            "https://api.github.com/repos/${github_user}/${repo_name}" 2>/dev/null || echo "000")
        if [ "$http_code" = "200" ]; then
            has_github_repo=true
            echo "     GitHub: https://github.com/${github_user}/${repo_name}"
        fi
    fi

    echo ""

    # 确认删除
    if [ "$force" != "--force" ]; then
        echo -e "  ${RED}⚠️  此操作不可恢复！${NC}"
        echo ""
        echo -n "  确认删除本地数据？(y/N): "
        read -r confirm_local
        if [[ ! "$confirm_local" =~ ^[yY]$ ]]; then
            log_info "已取消"
            return 0
        fi

        # 如果有 GitHub 仓库，询问是否也删除
        if $has_github_repo; then
            echo ""
            echo -n "  同时删除 GitHub 仓库 ${repo_name}？(y/N): "
            read -r confirm_github
            if [[ "$confirm_github" =~ ^[yY]$ ]]; then
                delete_github_repo "$github_user" "$repo_name"
            else
                log_info "保留 GitHub 仓库"
            fi
        fi
    else
        # --force 模式：删除本地，保留 GitHub
        log_warn "force 模式：删除本地数据，保留 GitHub 仓库"
    fi

    # 停止关联的定时器
    if [ -f "/tmp/openclaw-resume-sync.pid" ]; then
        local pid
        pid=$(cat "/tmp/openclaw-resume-sync.pid")
        if kill -0 "$pid" 2>/dev/null; then
            # 检查定时器是否属于这个项目（通过检查进程命令行）
            if cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ' | grep -q "$project_name"; then
                kill "$pid" 2>/dev/null
                rm -f "/tmp/openclaw-resume-sync.pid"
                log_info "已停止关联的定时器"
            fi
        fi
    fi

    # 删除本地目录
    log_step "删除本地数据..."
    rm -rf "$state_dir"
    log_info "✅ 本地数据已删除: ${state_dir}"

    # 检查是否还有其他项目
    local remaining
    remaining=$(count_projects)
    if [ "$remaining" -eq 0 ]; then
        echo ""
        log_info "所有项目已删除，目录 ${OPENCLAW_RESUME_BASE} 为空"
    else
        log_info "剩余 ${remaining} 个项目"
    fi

    echo ""
}

# 删除 GitHub 仓库
delete_github_repo() {
    local github_user="$1"
    local repo_name="$2"

    log_step "删除 GitHub 仓库: ${github_user}/${repo_name}..."

    local http_code
    http_code=$(timeout 10 curl -s -o /dev/null -w "%{http_code}" -X DELETE \
        -H "Authorization: token ${OPENCLAW_RESUME_PAT}" \
        "https://api.github.com/repos/${github_user}/${repo_name}" 2>/dev/null || echo "000")

    case "$http_code" in
        204) log_info "✅ GitHub 仓库已删除" ;;
        403) log_warn "GitHub 仓库删除失败（权限不足），请手动删除" ;;
        404) log_warn "GitHub 仓库不存在（可能已删除）" ;;
        *)   log_warn "GitHub 仓库删除失败 (HTTP ${http_code})，请手动删除" ;;
    esac
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    resume-delete "$@"
fi
