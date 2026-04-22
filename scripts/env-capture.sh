#!/bin/bash
# ========================================
# env-capture: 捕获环境依赖
# ========================================

source "$(dirname "$0")/core.sh"

resume-env() {
    local project_name="${1:-}"

    if [ -z "$project_name" ]; then
        project_name=$(detect_active_project_env)
    fi

    if [ -z "$project_name" ]; then
        log_error "用法: resume-env [project-name]"
        return 1
    fi

    local state_dir
    state_dir=$(get_state_dir "$project_name")

    log_step "捕获环境依赖: ${project_name}"
    capture_environment "$state_dir"

    git -C "$state_dir" add -A
    git -C "$state_dir" commit -m "env: capture environment dependencies" 2>/dev/null || log_info "没有环境变化"
    git -C "$state_dir" push origin main 2>/dev/null || true

    log_info "✅ 环境依赖已捕获"
}

capture_environment() {
    local state_dir="$1"
    local env_dir="${state_dir}/environment"
    mkdir -p "$env_dir"

    # 1. Python 依赖
    log_info "  捕获 Python 依赖..."
    if command -v pip &>/dev/null; then
        pip freeze > "${env_dir}/requirements.txt" 2>/dev/null || pip3 freeze > "${env_dir}/requirements.txt" 2>/dev/null || true
    fi

    # 2. 系统包
    log_info "  捕获系统包..."
    if command -v dpkg &>/dev/null; then
        dpkg --get-selections 2>/dev/null | grep -v deinstall > "${env_dir}/apt-packages.txt" || true
    fi

    # 3. Node.js 依赖
    log_info "  捕获 Node.js 依赖..."
    if command -v npm &>/dev/null; then
        # 全局包列表
        npm ls -g --depth=0 --json 2>/dev/null > "${env_dir}/npm-global.json" || true
        # 工作区 package.json（如果存在）
        if [ -f "${OPENCLAW_RESUME_WORKSPACE}/package.json" ]; then
            cp "${OPENCLAW_RESUME_WORKSPACE}/package.json" "${env_dir}/package.json" 2>/dev/null || true
            # lock 文件
            [ -f "${OPENCLAW_RESUME_WORKSPACE}/package-lock.json" ] && \
                cp "${OPENCLAW_RESUME_WORKSPACE}/package-lock.json" "${env_dir}/package-lock.json" 2>/dev/null || true
        fi
    fi

    # 4. 关键环境变量
    log_info "  捕获环境变量..."
    {
        echo "# 关键环境变量快照"
        echo "# 生成时间: $(now_iso)"
        for var in PATH PYTHONPATH LANG LC_ALL NODE_PATH HOME SHELL; do
            [ -n "${!var:-}" ] && echo "${var}=${!var}"
        done
    } > "${env_dir}/env-vars.txt"

    # 4. 生成 setup.sh
    log_info "  生成环境恢复脚本..."
    generate_setup_script "$env_dir"

    # 5. 更新 progress.yaml 中的环境快照
    local progress_file="${state_dir}/progress.yaml"
    if [ -f "$progress_file" ]; then
        local now
        now=$(now_iso)
        local py_ver
        py_ver=$(python3 --version 2>/dev/null | awk '{print $2}' || echo "unknown")

        yaml_set "$progress_file" "environment_snapshot.captured_at" "$now"
        yaml_set "$progress_file" "environment_snapshot.python_version" "$py_ver"
    fi
}

generate_setup_script() {
    local env_dir="$1"

    cat > "${env_dir}/setup.sh" << 'SETUP_SCRIPT'
#!/bin/bash
# ========================================
# openclaw-resume 环境恢复脚本
# 自动生成，请勿手动编辑
# ========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="/tmp/openclaw-resume-setup.log"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "=== 开始恢复环境 ==="

# 1. 系统包
if [ -f "$SCRIPT_DIR/apt-packages.txt" ] && command -v apt-get &>/dev/null; then
    log "检查系统包差异..."

    # 提取需要安装的包
    NEED_INSTALL=""
    while IFS= read -r line; do
        pkg=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $2}')
        if [ "$status" = "install" ]; then
            if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
                NEED_INSTALL="$NEED_INSTALL $pkg"
            fi
        fi
    done < "$SCRIPT_DIR/apt-packages.txt"

    if [ -n "$NEED_INSTALL" ]; then
        log "安装缺失的系统包: $NEED_INSTALL"
        if [ "$(id -u)" -eq 0 ]; then
            apt-get update -qq 2>/dev/null || true
            apt-get install -y -qq $NEED_INSTALL 2>/dev/null || log "部分系统包安装失败"
        else
            log "需要 sudo 权限安装系统包"
            sudo apt-get update -qq 2>/dev/null || true
            sudo apt-get install -y -qq $NEED_INSTALL 2>/dev/null || log "部分系统包安装失败"
        fi
    else
        log "系统包无差异"
    fi
fi

# 2. Python 依赖
if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
    log "安装 Python 依赖..."

    # 检测差异
    if command -v pip &>/dev/null || command -v pip3 &>/dev/null; then
        PIP_CMD="pip"
        command -v pip3 &>/dev/null && PIP_CMD="pip3"

        # 对比已安装和需要安装的
        INSTALLED=$($PIP_CMD freeze 2>/dev/null || true)
        NEED_PIP=""

        while IFS= read -r req; do
            # 跳过空行和注释
            [[ -z "$req" || "$req" == \#* ]] && continue
            pkg_name=$(echo "$req" | sed 's/[<>=!].*//' | tr '[:upper:]' '[:lower:]' | tr '_' '-')
            if ! echo "$INSTALLED" | grep -qi "^${pkg_name}=="; then
                NEED_PIP="$NEED_PIP $req"
            fi
        done < "$SCRIPT_DIR/requirements.txt"

        if [ -n "$NEED_PIP" ]; then
            $PIP_CMD install -q $NEED_PIP 2>/dev/null || log "部分 Python 包安装失败"
        else
            log "Python 依赖无差异"
        fi
    fi
fi

# 3. Node.js 依赖
if command -v npm &>/dev/null; then
    # 优先用 environment 目录下的 package.json
    if [ -f "$SCRIPT_DIR/package.json" ]; then
        log "安装 Node.js 依赖 (from environment)..."
        WORK_DIR=$(mktemp -d)
        cp "$SCRIPT_DIR/package.json" "$WORK_DIR/"
        [ -f "$SCRIPT_DIR/package-lock.json" ] && cp "$SCRIPT_DIR/package-lock.json" "$WORK_DIR/"
        cd "$WORK_DIR" && npm install --silent 2>/dev/null || log "Node.js 依赖安装失败"
        rm -rf "$WORK_DIR"
    elif [ -f "$SCRIPT_DIR/../workspace/package.json" ]; then
        log "安装 Node.js 依赖 (from workspace)..."
        cd "$SCRIPT_DIR/../workspace"
        npm install --silent 2>/dev/null || log "Node.js 依赖安装失败"
    fi
fi

log "=== 环境恢复完成 ==="
SETUP_SCRIPT

    chmod +x "${env_dir}/setup.sh"
}

# 检测活动项目
detect_active_project_env() {
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
    resume-env "$@"
fi
