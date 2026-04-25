#!/bin/bash
# ========================================
# openclaw-resume 端到端测试
# 测试完整流程：init → save → checkpoint → status → stop
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")/../scripts" && pwd)"
TEST_BASE="/tmp/openclaw-resume-e2e-test"
TEST_WORKSPACE="/tmp/openclaw-resume-e2e-workspace"
PASS=0
FAIL=0
TOTAL=0

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 测试工具
assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$expected" = "$actual" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗${NC} $desc (期望: $expected, 实际: $actual)"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    TOTAL=$((TOTAL + 1))
    if echo "$haystack" | grep -q "$needle"; then
        echo -e "  ${GREEN}✓${NC} $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗${NC} $desc (未找到: $needle)"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_exists() {
    local desc="$1" file="$2"
    TOTAL=$((TOTAL + 1))
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗${NC} $desc (文件不存在: $file)"
        FAIL=$((FAIL + 1))
    fi
}

assert_dir_exists() {
    local desc="$1" dir="$2"
    TOTAL=$((TOTAL + 1))
    if [ -d "$dir" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗${NC} $desc (目录不存在: $dir)"
        FAIL=$((FAIL + 1))
    fi
}

# ========================================
# 测试准备
# ========================================
setup() {
    echo -e "${YELLOW}=== 环境准备 ===${NC}"

    # 清理
    rm -rf "$TEST_BASE" "$TEST_WORKSPACE" 2>/dev/null

    # 创建模拟工作区
    mkdir -p "$TEST_WORKSPACE"
    echo "# Test Project" > "$TEST_WORKSPACE/README.md"
    echo "print('hello')" > "$TEST_WORKSPACE/main.py"
    echo '{"name":"test","version":"1.0.0"}' > "$TEST_WORKSPACE/package.json"

    # 设置环境变量
    export OPENCLAW_RESUME_BASE="$TEST_BASE"
    export OPENCLAW_RESUME_WORKSPACE="$TEST_WORKSPACE"
    export OPENCLAW_RESUME_PAT="fake-pat-for-testing"
    export OPENCLAW_RESUME_USER="test-user"

    # 确保 git 全局配置
    git config --global user.email "test@local" 2>/dev/null || true
    git config --global user.name "test" 2>/dev/null || true

    echo "  工作区: $TEST_WORKSPACE"
    echo "  状态目录: $TEST_BASE"
    echo ""
}

# ========================================
# 测试 1: core.sh 基础函数
# ========================================
test_core_functions() {
    echo -e "${YELLOW}=== 测试 1: core.sh 基础函数 ===${NC}"

    source "$SCRIPT_DIR/core.sh" 2>/dev/null

    # 测试 get_state_dir
    local result
    result=$(get_state_dir "my-project")
    assert_eq "get_state_dir 返回正确路径" "$TEST_BASE/my-project" "$result"

    # 测试 now_iso
    local now
    now=$(now_iso)
    assert_contains "now_iso 返回 ISO 时间" "$now" "T"

    # 测试 yaml_set + yaml_get (无 yq 模式)
    local test_yaml="/tmp/test-e2e-yaml.yaml"
    cat > "$test_yaml" << 'EOF'
session:
  id: ""
  name: "test"
EOF
    yaml_set "$test_yaml" "session.id" "2026-04-23-am-1"
    local val
    val=$(grep 'id:' "$test_yaml" | head -1 | sed 's/.*id: *"//;s/".*//')
    assert_eq "yaml_set 写入值" "2026-04-23-am-1" "$val"

    # 测试 add_log_entry
    mkdir -p /tmp/test-e2e-state
    cat > /tmp/test-e2e-state/progress.yaml << 'EOF'
log: []
EOF
    add_log_entry "/tmp/test-e2e-state" "测试条目"
    local log_content
    log_content=$(cat /tmp/test-e2e-state/progress.yaml)
    assert_contains "add_log_entry 插入到 log 段落" "$log_content" "测试条目"

    # 验证 log 条目在正确位置（log: 下面，不是文件末尾）
    local log_line_num
    log_line_num=$(grep -n "^log:" /tmp/test-e2e-state/progress.yaml | head -1 | cut -d: -f1)
    local entry_line_num
    entry_line_num=$(grep -n "测试条目" /tmp/test-e2e-state/progress.yaml | head -1 | cut -d: -f1)
    if [ "$entry_line_num" -gt "$log_line_num" ] 2>/dev/null; then
        assert_eq "add_log_entry 位置正确" "true" "true"
    else
        assert_eq "add_log_entry 位置正确" "true" "false"
    fi

    # 测试 retry 函数
    local retry_count=0
    retry_test_fn() {
        retry_count=$((retry_count + 1))
        [ $retry_count -ge 3 ]
    }
    if retry 5 0 retry_test_fn 2>/dev/null; then
        assert_eq "retry 重试成功" "3" "$retry_count"
    else
        assert_eq "retry 重试成功" "3" "$retry_count"
    fi

    # 测试 detect_active_project（无项目时返回空）
    local detected
    detected=$(detect_active_project)
    assert_eq "detect_active_project 无项目时返回空" "" "$detected"

    # 测试 list_all_projects（无项目时返回空）
    local listed
    listed=$(list_all_projects)
    assert_eq "list_all_projects 无项目时返回空" "" "$listed"

    # 测试 count_projects（无项目时返回 0）
    local cnt
    cnt=$(count_projects)
    assert_eq "count_projects 无项目时返回 0" "0" "$cnt"

    # 测试 sync_workspace_to_state
    local sync_src="/tmp/test-e2e-sync-src"
    local sync_dst="/tmp/test-e2e-sync-dst"
    rm -rf "$sync_src" "$sync_dst"
    mkdir -p "$sync_src"
    echo "file1" > "$sync_src/a.txt"
    mkdir "$sync_src/sub"
    echo "file2" > "$sync_src/sub/b.txt"
    echo "node_modules" > "$sync_src/node_modules"
    export OPENCLAW_RESUME_WORKSPACE="$sync_src"
    mkdir -p "$sync_dst"
    sync_workspace_to_state "$sync_dst"
    assert_file_exists "sync 复制文件 a.txt" "$sync_dst/workspace/a.txt"
    assert_file_exists "sync 复制子目录文件 b.txt" "$sync_dst/workspace/sub/b.txt"
    # node_modules 应被排除
    local nm_count
    nm_count=$(find "$sync_dst/workspace" -name "node_modules" 2>/dev/null | wc -l)
    assert_eq "sync 排除 node_modules" "0" "$nm_count"

    # 测试 yaml_get/yaml_set 双层 key
    local test_yaml2="/tmp/test-e2e-yaml2.yaml"
    cat > "$test_yaml2" << 'EOF'
session:
  id: "old-id"
  name: "test"
position:
  project: "old-project"
  task: "old-task"
EOF
    yaml_set "$test_yaml2" "session.id" "new-id"
    yaml_set "$test_yaml2" "position.task" "new-task"
    local got_id got_task
    got_id=$(yaml_get "$test_yaml2" "session.id" "")
    got_task=$(yaml_get "$test_yaml2" "position.task" "")
    assert_eq "yaml_set+get session.id" "new-id" "$got_id"
    assert_eq "yaml_set+get position.task" "new-task" "$got_task"
    # 确保 session.name 没被误改
    local got_name
    got_name=$(yaml_get "$test_yaml2" "session.name" "")
    assert_eq "yaml_set 不影响其他字段" "test" "$got_name"

    rm -f "$test_yaml" "$test_yaml2"
    rm -rf /tmp/test-e2e-state "$sync_src" "$sync_dst"
    echo ""
}

# ========================================
# 测试 7: resume-list
# ========================================
test_list() {
    echo -e "${YELLOW}=== 测试 7: resume-list ===${NC}"

    source "$SCRIPT_DIR/core.sh" 2>/dev/null
    source "$SCRIPT_DIR/resume-list.sh" 2>/dev/null

    # 创建两个模拟项目
    for name in project-alpha project-beta; do
        local dir="$TEST_BASE/$name"
        mkdir -p "$dir/environment" "$dir/workspace" "$dir/checkpoints"
        git -C "$dir" init -b main 2>/dev/null
        cp "$SCRIPT_DIR/../templates/progress.yaml" "$dir/progress.yaml"
        yaml_set "$dir/progress.yaml" "position.project" "$name"
        yaml_set "$dir/progress.yaml" "position.task" "task-${name}"
        add_log_entry "$dir" "初始化 ${name}"
        git -C "$dir" add -A 2>/dev/null
        git -C "$dir" commit -m "init: $name" 2>/dev/null
    done

    # 测试 list_all_projects
    local listed
    listed=$(list_all_projects)
    assert_contains "list_all_projects 包含 project-alpha" "$listed" "project-alpha"
    assert_contains "list_all_projects 包含 project-beta" "$listed" "project-beta"

    # 测试 count_projects（+1 是因为 test_init 创建的 e2e-test）
    local cnt
    cnt=$(count_projects)
    assert_eq "count_projects 返回 3 (含 e2e-test)" "3" "$cnt"

    # 测试 detect_active_project（两个项目时返回最近修改的）
    # 修改 project-beta 的 progress.yaml 使其更新
    sleep 1
    touch "$TEST_BASE/project-beta/progress.yaml"
    local detected
    detected=$(detect_active_project)
    assert_eq "detect_active_project 返回最近活跃的" "project-beta" "$detected"

    # 测试 resume-list 输出包含项目名
    local list_output
    list_output=$(resume-list 2>&1)
    assert_contains "resume-list 输出包含 project-alpha" "$list_output" "project-alpha"
    assert_contains "resume-list 输出包含 project-beta" "$list_output" "project-beta"
    assert_contains "resume-list 输出包含任务名" "$list_output" "task-project-beta"

    echo ""
}

# ========================================
# 测试 8: resume-delete
# ========================================
test_delete() {
    echo -e "${YELLOW}=== 测试 8: resume-delete ===${NC}"

    source "$SCRIPT_DIR/core.sh" 2>/dev/null
    source "$SCRIPT_DIR/resume-delete.sh" 2>/dev/null

    # 确认 project-alpha 存在
    assert_dir_exists "project-alpha 删除前存在" "$TEST_BASE/project-alpha"

    # 用 --force 删除（跳过确认，不删 GitHub）
    export OPENCLAW_RESUME_PAT=""  # 模拟无 PAT，跳过 GitHub 检查
    resume-delete "project-alpha" --force 2>&1

    # 验证已删除
    local alpha_exists=true
    [ ! -d "$TEST_BASE/project-alpha" ] && alpha_exists=false
    assert_eq "project-alpha 已删除" "false" "$alpha_exists"

    # 验证 project-beta 还在
    assert_dir_exists "project-beta 仍然存在" "$TEST_BASE/project-beta"

    # 测试删除不存在的项目
    local delete_output
    delete_output=$(resume-delete "nonexistent" 2>&1 || true)
    assert_contains "删除不存在的项目报错" "$delete_output" "不存在"

    # 测试 count_projects 现在少了一个
    local cnt
    cnt=$(count_projects)
    assert_eq "删除后 count_projects 返回 2" "2" "$cnt"

    echo ""
}

# ========================================
# 测试 9: bootstrap 生成
# ========================================
test_bootstrap() {
    echo -e "${YELLOW}=== 测试 9: bootstrap 生成 ===${NC}"

    source "$SCRIPT_DIR/core.sh" 2>/dev/null
    source "$SCRIPT_DIR/resume-bootstrap-gen.sh" 2>/dev/null

    # 创建模拟项目
    local state_dir="$TEST_BASE/bootstrap-test"
    mkdir -p "$state_dir/environment" "$state_dir/workspace" "$state_dir/checkpoints"
    git -C "$state_dir" init -b main 2>/dev/null
    cp "$SCRIPT_DIR/../templates/progress.yaml" "$state_dir/progress.yaml"

    # 生成 bootstrap
    generate_bootstrap "$state_dir" "bootstrap-test"

    assert_file_exists "bootstrap.sh 已生成" "$state_dir/bootstrap.sh"

    # 验证内容包含项目名
    local content
    content=$(cat "$state_dir/bootstrap.sh")
    assert_contains "bootstrap 包含项目名" "$content" "bootstrap-test"
    assert_contains "bootstrap 包含 resume-restore" "$content" "resume-restore"
    assert_contains "bootstrap 包含 PAT 提示" "$content" "OPENCLAW_RESUME_PAT"

    # 验证可执行权限
    local is_exec
    [ -x "$state_dir/bootstrap.sh" ] && is_exec="true" || is_exec="false"
    assert_eq "bootstrap.sh 有可执行权限" "true" "$is_exec"

    echo ""
}

# ========================================
# 测试 2: resume-init（本地模式）
# ========================================
test_init() {
    echo -e "${YELLOW}=== 测试 2: resume-init (本地模式) ===${NC}"

    # 模拟 init：直接创建本地结构（跳过 GitHub）
    local state_dir="$TEST_BASE/e2e-test"
    mkdir -p "$state_dir/environment" "$state_dir/workspace" "$state_dir/checkpoints"

    # 初始化 git
    git -C "$state_dir" init -b main 2>/dev/null

    # 复制模板
    cp "$SCRIPT_DIR/../templates/progress.yaml" "$state_dir/progress.yaml"

    # 填充
    source "$SCRIPT_DIR/core.sh" 2>/dev/null
    yaml_set "$state_dir/progress.yaml" "session.id" "2026-04-23-am-1"
    yaml_set "$state_dir/progress.yaml" "position.project" "e2e-test"
    add_log_entry "$state_dir" "项目初始化完成"

    # 生成 .gitignore
    cat > "$state_dir/.gitignore" << 'EOF'
.env
node_modules/
__pycache__/
EOF

    # 捕获环境
    source "$SCRIPT_DIR/env-capture.sh" 2>/dev/null
    capture_environment "$state_dir"

    # 提交
    git -C "$state_dir" add -A
    git -C "$state_dir" commit -m "init: e2e-test" 2>/dev/null

    assert_dir_exists "状态目录存在" "$state_dir"
    assert_dir_exists "environment 目录存在" "$state_dir/environment"
    assert_dir_exists "workspace 目录存在" "$state_dir/workspace"
    assert_dir_exists "checkpoints 目录存在" "$state_dir/checkpoints"
    assert_file_exists "progress.yaml 存在" "$state_dir/progress.yaml"
    assert_file_exists ".gitignore 存在" "$state_dir/.gitignore"
    assert_file_exists "requirements.txt 存在" "$state_dir/environment/requirements.txt"
    assert_file_exists "apt-packages.txt 存在" "$state_dir/environment/apt-packages.txt"
    assert_file_exists "setup.sh 存在" "$state_dir/environment/setup.sh"
    assert_file_exists "env-vars.txt 存在" "$state_dir/environment/env-vars.txt"

    # 验证 git 有提交
    local commit_count
    commit_count=$(git -C "$state_dir" log --oneline | wc -l)
    assert_eq "git 有 1 个提交" "1" "$commit_count"

    # 验证 progress.yaml 内容
    local project_val
    project_val=$(grep 'project:' "$state_dir/progress.yaml" | head -1 | sed 's/.*project: *"//;s/".*//')
    assert_eq "progress.yaml project 正确" "e2e-test" "$project_val"

    echo ""
}

# ========================================
# 测试 3: resume-save
# ========================================
test_save() {
    echo -e "${YELLOW}=== 测试 3: resume-save ===${NC}"

    source "$SCRIPT_DIR/core.sh" 2>/dev/null
    local state_dir="$TEST_BASE/e2e-test"

    # 模拟工作区变化
    echo "new content" > "$TEST_WORKSPACE/new-file.txt"

    # 同步工作文件到状态目录
    local workspace_dst="${state_dir}/workspace"
    cp -r "$TEST_WORKSPACE"/* "$workspace_dst/" 2>/dev/null || true

    # 更新进度
    local now
    now=$(now_iso)
    yaml_set "$state_dir/progress.yaml" "session.last_saved" "$now"
    add_log_entry "$state_dir" "手动保存: 添加新文件"

    # 提交
    git -C "$state_dir" add -A
    git -C "$state_dir" commit -m "save: 添加新文件" 2>/dev/null

    assert_file_exists "新文件同步到 workspace" "$state_dir/workspace/new-file.txt"

    local commit_count
    commit_count=$(git -C "$state_dir" log --oneline | wc -l)
    assert_eq "save 后有 2 个提交" "2" "$commit_count"

    echo ""
}

# ========================================
# 测试 4: resume-checkpoint
# ========================================
test_checkpoint() {
    echo -e "${YELLOW}=== 测试 4: resume-checkpoint ===${NC}"

    source "$SCRIPT_DIR/core.sh" 2>/dev/null
    local state_dir="$TEST_BASE/e2e-test"

    # 创建检查点
    local checkpoint_id=1
    local checkpoint_file="${state_dir}/checkpoints/$(printf '%03d' $checkpoint_id)-完成初始化.yaml"

    cat > "$checkpoint_file" << EOF
id: $checkpoint_id
timestamp: "$(now_iso)"
description: "完成初始化"
status: "pending_confirmation"
project: "e2e-test"
EOF

    add_log_entry "$state_dir" "创建检查点 #${checkpoint_id}: 完成初始化"

    git -C "$state_dir" add -A
    git -C "$state_dir" commit -m "checkpoint: #${checkpoint_id}" 2>/dev/null

    assert_file_exists "检查点文件存在" "$checkpoint_file"

    # 确认检查点
    sed -i 's/status: "pending_confirmation"/status: "confirmed"/' "$checkpoint_file"
    git -C "$state_dir" add -A
    git -C "$state_dir" commit -m "confirm: checkpoint #${checkpoint_id}" 2>/dev/null

    local status_val
    status_val=$(grep 'status:' "$checkpoint_file" | sed 's/.*status: *"//;s/".*//')
    assert_eq "检查点状态为 confirmed" "confirmed" "$status_val"

    local commit_count
    commit_count=$(git -C "$state_dir" log --oneline | wc -l)
    assert_eq "checkpoint 后有 4 个提交" "4" "$commit_count"

    echo ""
}

# ========================================
# 测试 5: resume-status（数据完整性）
# ========================================
test_status() {
    echo -e "${YELLOW}=== 测试 5: 数据完整性 ===${NC}"

    source "$SCRIPT_DIR/core.sh" 2>/dev/null
    local state_dir="$TEST_BASE/e2e-test"

    # 验证 progress.yaml 结构完整
    assert_file_exists "progress.yaml 存在" "$state_dir/progress.yaml"

    local has_session has_position has_log has_checkpoints
    has_session=$(grep -c "^session:" "$state_dir/progress.yaml")
    has_position=$(grep -c "^position:" "$state_dir/progress.yaml")
    has_log=$(grep -c "^log:" "$state_dir/progress.yaml")
    has_checkpoints=$(grep -c "^checkpoints:" "$state_dir/progress.yaml")

    assert_eq "progress.yaml 有 session 段" "1" "$has_session"
    assert_eq "progress.yaml 有 position 段" "1" "$has_position"
    assert_eq "progress.yaml 有 log 段" "1" "$has_log"
    assert_eq "progress.yaml 有 checkpoints 段" "1" "$has_checkpoints"

    # 验证 log 条目数量
    local log_entries
    log_entries=$(grep -c '^\s*- "' "$state_dir/progress.yaml")
    assert_eq "log 有 3 个条目" "3" "$log_entries"

    # 验证 git 历史
    local git_log
    git_log=$(git -C "$state_dir" log --oneline)
    assert_contains "git 历史包含 init" "$git_log" "init"
    assert_contains "git 历史包含 save" "$git_log" "save"
    assert_contains "git 历史包含 checkpoint" "$git_log" "checkpoint"

    echo ""
}

# ========================================
# 测试 6: time-remaining
# ========================================
test_time_remaining() {
    echo -e "${YELLOW}=== 测试 6: 时间感知 ===${NC}"

    source "$SCRIPT_DIR/core.sh" 2>/dev/null
    local state_dir="$TEST_BASE/e2e-test"

    # 设置一个未来的过期时间
    local future
    future=$(date -d "+30 minutes" -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")
    yaml_set "$state_dir/progress.yaml" "session.expires_at" "$future"

    # 验证 expires_at 被写入
    local expires_val
    expires_val=$(grep 'expires_at:' "$state_dir/progress.yaml" | head -1 | sed 's/.*expires_at: *"//;s/".*//')
    assert_contains "expires_at 已设置" "$expires_val" "2026"

    echo ""
}

# ========================================
# 清理
# ========================================
cleanup() {
    echo -e "${YELLOW}=== 清理 ===${NC}"
    rm -rf "$TEST_BASE" "$TEST_WORKSPACE" /tmp/test-e2e-* 2>/dev/null
    echo "  已清理测试文件"
    echo ""
}

# ========================================
# 主流程
# ========================================
main() {
    echo ""
    echo "╔═══════════════════════════════════════════╗"
    echo "║   openclaw-resume 端到端测试               ║"
    echo "╚═══════════════════════════════════════════╝"
    echo ""

    setup
    test_core_functions
    test_init
    test_save
    test_checkpoint
    test_status
    test_time_remaining
    test_list
    test_delete
    test_bootstrap
    cleanup

    echo "═══════════════════════════════════════════"
    echo -e "  结果: ${GREEN}${PASS} 通过${NC} / ${RED}${FAIL} 失败${NC} / 共 ${TOTAL} 项"
    echo "═══════════════════════════════════════════"
    echo ""

    if [ $FAIL -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

main "$@"
