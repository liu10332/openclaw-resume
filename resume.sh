#!/bin/bash
# ========================================
# resume - openclaw-resume 统一入口
# 用法: resume <command> [args...]
# ========================================

set -euo pipefail

# 定位脚本目录
RESUME_HOME="${OPENCLAW_RESUME_HOME:-$HOME/.openclaw-resume}"
RESUME_BIN="${RESUME_HOME}/bin"
RESUME_SCRIPTS="${RESUME_BIN}/scripts"

# 版本
VERSION="0.2.0"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    echo ""
    echo "  openclaw-resume v${VERSION} — 限时试用环境跨会话续接工具"
    echo ""
    echo "  用法: resume <command> [args...]"
    echo ""
    echo "  项目管理:"
    echo "    init <name> [dir]      初始化新项目"
    echo "    restore [name]         恢复上次会话"
    echo "    list [-a]              列出所有项目"
    echo "    delete <name> [--force] 删除项目"
    echo "    status [name]          查看状态"
    echo ""
    echo "  工作保存:"
    echo "    save [message]         保存当前状态"
    echo "    checkpoint <desc>      创建检查点"
    echo "    diff                   显示上次保存后的变化"
    echo ""
    echo "  环境:"
    echo "    env [name]             捕获环境依赖"
    echo "    env-restore [name]     恢复环境依赖"
    echo ""
    echo "  定时器:"
    echo "    timer start [name]     启动自动同步"
    echo "    timer stop             停止自动同步"
    echo "    timer status           查看定时器状态"
    echo ""
    echo "  时间:"
    echo "    time [name]            查看剩余时间"
    echo "    ask-time [name]        设置剩余时间"
    echo ""
    echo "  其他:"
    echo "    version                查看版本"
    echo "    uninstall              卸载工具"
    echo "    help                   显示此帮助"
    echo ""
    echo "  前置条件:"
    echo "    export OPENCLAW_RESUME_PAT=\"ghp_你的token\""
    echo "    export OPENCLAW_RESUME_USER=\"你的github用户名\""
    echo ""
}

show_version() {
    echo "openclaw-resume v${VERSION}"
}

# 检查脚本是否存在
check_install() {
    if [ ! -d "$RESUME_SCRIPTS" ]; then
        echo -e "${RED}[ERROR]${NC} openclaw-resume 未安装或安装不完整"
        echo "请重新安装: curl -sL https://raw.githubusercontent.com/liu10332/openclaw-resume/main/install.sh | bash"
        exit 1
    fi
}

# 主入口
CMD="${1:-}"
shift 2>/dev/null || true

case "$CMD" in
    init)
        check_install
        source "${RESUME_SCRIPTS}/core.sh"
        source "${RESUME_SCRIPTS}/resume-init.sh"
        resume-init "$@"
        ;;
    restore)
        check_install
        source "${RESUME_SCRIPTS}/core.sh"
        source "${RESUME_SCRIPTS}/resume-restore.sh"
        resume-restore "$@"
        ;;
    save)
        check_install
        source "${RESUME_SCRIPTS}/core.sh"
        source "${RESUME_SCRIPTS}/resume-save.sh"
        resume-save "$@"
        ;;
    checkpoint)
        check_install
        source "${RESUME_SCRIPTS}/core.sh"
        source "${RESUME_SCRIPTS}/resume-checkpoint.sh"
        resume-checkpoint "$@"
        ;;
    status)
        check_install
        source "${RESUME_SCRIPTS}/core.sh"
        source "${RESUME_SCRIPTS}/resume-status.sh"
        resume-status "$@"
        ;;
    list|ls)
        check_install
        source "${RESUME_SCRIPTS}/core.sh"
        source "${RESUME_SCRIPTS}/resume-list.sh"
        resume-list "$@"
        ;;
    delete|rm)
        check_install
        source "${RESUME_SCRIPTS}/core.sh"
        source "${RESUME_SCRIPTS}/resume-delete.sh"
        resume-delete "$@"
        ;;
    env)
        check_install
        source "${RESUME_SCRIPTS}/core.sh"
        source "${RESUME_SCRIPTS}/env-capture.sh"
        resume-env "$@"
        ;;
    env-restore)
        check_install
        source "${RESUME_SCRIPTS}/core.sh"
        source "${RESUME_SCRIPTS}/env-restore.sh"
        env-restore "$@"
        ;;
    timer)
        check_install
        source "${RESUME_SCRIPTS}/core.sh"
        source "${RESUME_SCRIPTS}/resume-timer.sh"
        resume-timer "$@"
        ;;
    time|time-remaining)
        check_install
        source "${RESUME_SCRIPTS}/core.sh"
        source "${RESUME_SCRIPTS}/resume-time-remaining.sh"
        resume-time-remaining "$@"
        ;;
    ask-time)
        check_install
        source "${RESUME_SCRIPTS}/core.sh"
        source "${RESUME_SCRIPTS}/resume-ask-time.sh"
        resume-ask-time "$@"
        ;;
    diff)
        check_install
        source "${RESUME_SCRIPTS}/core.sh"
        # 显示上次保存后的变化
        project_name="${1:-}"
        if [ -z "$project_name" ]; then
            project_name=$(detect_active_project)
        fi
        if [ -z "$project_name" ]; then
            echo -e "${RED}[ERROR]${NC} 未找到项目"
            exit 1
        fi
        state_dir=$(get_state_dir "$project_name")
        if [ -d "${state_dir}/.git" ]; then
            git -C "$state_dir" diff --stat
        else
            echo "无 git 仓库"
        fi
        ;;
    version|--version|-v)
        show_version
        ;;
    help|--help|-h)
        show_help
        ;;
    uninstall)
        check_install
        echo ""
        echo -e "${YELLOW}⚠️  即将卸载 openclaw-resume${NC}"
        echo "   安装目录: ${RESUME_BIN}"
        echo "   数据目录: ${RESUME_HOME}（项目数据保留）"
        echo ""
        echo -n "确认卸载？(y/N): "
        read -r confirm
        if [[ "$confirm" =~ ^[yY]$ ]]; then
            # 删除安装文件（保留项目数据）
            rm -rf "$RESUME_BIN"
            # 从 PATH 中移除
            for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
                if [ -f "$rc" ]; then
                    sed -i '/# openclaw-resume/d' "$rc"
                    sed -i "\|${RESUME_BIN}|d" "$rc"
                fi
            done
            echo -e "${GREEN}✅ 已卸载${NC}"
            echo "   项目数据保留在: ${RESUME_HOME}/"
            echo "   如需彻底清理: rm -rf ${RESUME_HOME}"
        else
            echo "已取消"
        fi
        ;;
    "")
        show_help
        ;;
    *)
        echo -e "${RED}[ERROR]${NC} 未知命令: ${CMD}"
        echo "运行 resume help 查看可用命令"
        exit 1
        ;;
esac
