#!/bin/bash
# ========================================
# env-restore: 独立环境恢复脚本
# 可单独执行，也可被 resume-restore 调用
# ========================================

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

env-restore() {
    local project_name="${1:-}"

    if [ -z "$project_name" ]; then
        project_name=$(detect_active_project_env_restore)
    fi

    if [ -z "$project_name" ]; then
        log_error "用法: env-restore [project-name]"
        return 1
    fi

    local state_dir
    state_dir=$(get_state_dir "$project_name")
    local setup_script="${state_dir}/environment/setup.sh"

    if [ ! -d "${state_dir}/environment" ]; then
        log_error "未找到环境目录: ${state_dir}/environment"
        log_info "请先运行 resume-init 或 resume-env 捕获环境"
        return 1
    fi

    log_step "恢复环境依赖: ${project_name}"

    # 显示将要恢复的内容
    echo ""
    echo "  ┌─ 环境快照 ─────────────────────────────────┐"
    [ -f "${state_dir}/environment/apt-packages.txt" ] && \
        echo "  │ 系统包: $(wc -l < "${state_dir}/environment/apt-packages.txt") 个"
    [ -f "${state_dir}/environment/requirements.txt" ] && \
        echo "  │ Python: $(wc -l < "${state_dir}/environment/requirements.txt") 个包"
    [ -f "${state_dir}/environment/package.json" ] && \
        echo "  │ Node.js: package.json 存在"
    [ -f "${state_dir}/environment/npm-global.json" ] && \
        echo "  │ npm 全局: 已捕获"
    echo "  └────────────────────────────────────────────┘"
    echo ""

    # 执行 setup.sh
    if [ -f "$setup_script" ]; then
        log_step "执行环境恢复脚本..."
        bash "$setup_script"
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            log_info "✅ 环境恢复完成"
        else
            log_warn "环境恢复部分失败 (exit: $exit_code)，请手动检查"
        fi
    else
        log_warn "setup.sh 不存在，跳过自动恢复"
        log_info "可手动安装依赖后运行: resume-env ${project_name}"
    fi

    # 恢复工作区文件（如果有 package.json，安装依赖）
    local workspace_dir="${OPENCLAW_RESUME_WORKSPACE}"
    if [ -f "${state_dir}/environment/package.json" ] && command -v npm &>/dev/null; then
        if [ ! -f "${workspace_dir}/package.json" ]; then
            log_info "恢复 package.json 到工作区..."
            cp "${state_dir}/environment/package.json" "${workspace_dir}/"
            [ -f "${state_dir}/environment/package-lock.json" ] && \
                cp "${state_dir}/environment/package-lock.json" "${workspace_dir}/"
            cd "$workspace_dir" && npm install --silent 2>/dev/null || log_warn "npm install 部分失败"
        fi
    fi
}

# 检测活动项目
detect_active_project_env_restore() {
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
    env-restore "$@"
fi
