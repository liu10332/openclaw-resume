#!/bin/bash
# ========================================
# resume-init: 初始化项目状态仓库
# ========================================

source "$(dirname "$0")/core.sh"
source "$(dirname "$0")/env-capture.sh"

resume-init() {
    local project_name="${1:-}"

    if [ -z "$project_name" ]; then
        log_error "用法: resume-init <project-name>"
        return 1
    fi

    log_step "初始化 openclaw-resume 项目: ${project_name}"

    # 1. 检查前置条件
    check_prerequisites || return 1

    local state_dir
    state_dir=$(get_state_dir "$project_name")
    local repo_name="${project_name}-state"

    # 2. 检查是否已初始化
    if [ -d "$state_dir/.git" ]; then
        log_warn "项目 ${project_name} 已初始化，使用 resume-restore 恢复"
        return 0
    fi

    # 3. 创建 GitHub 仓库（使用 gh CLI 或提示手动创建）
    log_step "创建 GitHub 仓库..."
    if command -v gh &>/dev/null; then
        gh repo create "${OPENCLAW_RESUME_USER}/${repo_name}" \
            --private \
            --description "openclaw-resume state for ${project_name}" \
            2>/dev/null || log_warn "仓库可能已存在或 gh CLI 认证失败，请手动创建"
    else
        log_warn "gh CLI 未安装，请手动在 GitHub 创建仓库: ${repo_name}（private）"
        log_info "创建后按回车继续..."
        read -r
    fi

    # 4. 克隆仓库
    log_step "克隆状态仓库..."
    mkdir -p "$OPENCLAW_RESUME_BASE"
    local clone_url="https://${OPENCLAW_RESUME_PAT}@github.com/${OPENCLAW_RESUME_USER}/${repo_name}.git"

    if ! git clone "$clone_url" "$state_dir" 2>/dev/null; then
        # 如果仓库为空，初始化本地再推送
        mkdir -p "$state_dir"
        git -C "$state_dir" init
        git -C "$state_dir" remote add origin "$clone_url"
    fi

    # 5. 创建目录结构
    log_step "创建目录结构..."
    mkdir -p environment workspace checkpoints

    # 6. 生成 progress.yaml
    log_step "生成进度文件..."
    local session_id
    session_id=$(generate_session_id "$project_name")
    local now
    now=$(now_iso)
    local expires
    expires=$(calc_expires_at)

    cp "$(dirname "$0")/../templates/progress.yaml" progress.yaml

    # 填充初始值
    yaml_set progress.yaml "session.id" "$session_id"
    yaml_set progress.yaml "session.started" "$now"
    yaml_set progress.yaml "session.expires_at" "$expires"
    yaml_set progress.yaml "session.last_saved" "$now"
    yaml_set progress.yaml "position.project" "$project_name"

    # 追加初始 log 条目
    add_log_entry "$state_dir" "项目初始化完成"

    # 7. 生成 .gitignore
    cat > .gitignore << 'EOF'
# openclaw-resume 排除文件
.env
*.key
*.pem
__pycache__/
node_modules/
.venv/
*.pyc
*.pyo
*.egg-info/
.DS_Store
Thumbs.db
EOF

    # 7. 捕获环境
    log_step "捕获环境依赖..."
    # 传入 state_dir 直接捕获，避免依赖项目检测
    capture_environment "$state_dir"

    # 8. 提交并推送
    log_step "提交并推送..."
    git -C "$state_dir" add -A
    git -C "$state_dir" commit -m "init: ${project_name} state initialized"
    
    # 强制设置主分支为 main 并推送
    git -C "$state_dir" branch -M main
    if git -C "$state_dir" remote | grep -q "origin"; then
        git -C "$state_dir" push -u origin main
    else
        log_warn "未找到远程仓库 origin，请手动关联并推送"
        log_info "git remote add origin https://github.com/${OPENCLAW_RESUME_USER}/${repo_name}.git"
        log_info "git push -u origin main"
    fi

    log_info "✅ 项目 ${project_name} 初始化完成"
    log_info "📁 状态目录: ${state_dir}"
    log_info "🔗 GitHub: https://github.com/${OPENCLAW_RESUME_USER}/${repo_name}"
    log_info ""

    # 10. 询问剩余时间
    log_step "设置环境剩余时间..."
    bash "$(dirname "$0")/resume-ask-time.sh" "$project_name" ""

    log_info "下一步:"
    log_info "  1. 正常工作..."
    log_info "  2. 运行 resume-timer start 启动自动同步"
    log_info "  3. 关键步骤后运行 resume-checkpoint <描述>"
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    resume-init "$@"
fi
