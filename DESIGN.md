# openclaw-resume 详细设计文档

> 创建日期：2026-04-22
> 状态：已批准
> 版本：0.1.0

## 1. 概述

### 1.1 问题背景

在线 OpenClaw 试用环境存在以下限制：
- 每次限时 **1小时**，到期自动销毁虚拟空间
- 所有本地数据（代码、配置、进度）全部丢失
- 用户需要从零开始，无法接续上次的工作

### 1.2 解决方案

设计一套 **OpenClaw Skill**，在限时环境中实现：
1. **进度追踪** — 关键节点触发记录（1小时约6-12条）
2. **自动同步** — 每15分钟自动将工作状态推送到 GitHub
3. **环境恢复** — 不仅恢复文件，还能恢复依赖环境
4. **断点续接** — 下次试用时自动拉取上次的进度，从检查点继续

### 1.3 设计原则

- **轻量** — 不依赖复杂框架，纯 shell 脚本实现
- **安全** — 只同步到用户指定的 GitHub 仓库，不泄露凭证
- **可靠** — 同步失败不影响正常工作，有重试机制
- **易用** — 一条命令初始化，自动运行

## 2. 架构设计

### 2.1 整体架构

```
┌─────────────────────────────────────────────────────────┐
│                  OpenClaw Online Environment             │
│                                                         │
│  ┌──────────┐   ┌──────────┐   ┌───────────────────┐   │
│  │ Agent    │──▶│ Skill    │──▶│ Progress Tracker  │   │
│  │ (你)     │   │ Core     │   │ (progress.yaml)   │   │
│  └──────────┘   └──────────┘   └───────────────────┘   │
│       │              │                    │              │
│       │         ┌────┴────┐         ┌─────┴──────┐      │
│       │         │ Auto    │         │ Env Capture│      │
│       │         │ Sync    │         │ (pip/npm)  │      │
│       │         │ Timer   │         └────────────┘      │
│       │         └────┬────┘                               │
│       │              │                                    │
│       └──────────────┼───────────────────────────────────┘
│                      │
└──────────────────────┼───────────────────────────────────┘
                       │ git push/pull (HTTPS + PAT)
                       ▼
              ┌──────────────────┐
              │  GitHub Repo     │
              │  (project-state) │
              │                  │
              │  /progress.yaml  │
              │  /environment/   │
              │  /workspace/     │
              │  /checkpoints/   │
              └──────────────────┘
```

### 2.2 组件划分

| 组件 | 文件 | 职责 |
|------|------|------|
| Skill 入口 | `SKILL.md` | 定义 skill 元信息、使用说明 |
| 核心库 | `scripts/core.sh` | 共享函数（颜色输出、YAML 操作、工具函数） |
| 初始化 | `scripts/resume-init.sh` | 项目初始化，创建 GitHub 状态仓库 |
| 恢复 | `scripts/resume-restore.sh` | 从 GitHub 恢复状态、文件、环境 |
| 保存 | `scripts/resume-save.sh` | 手动保存当前状态 |
| 检查点 | `scripts/resume-checkpoint.sh` | 检查点创建和确认 |
| 环境捕获 | `scripts/env-capture.sh` | 生成 requirements.txt + setup.sh |
| 定时器 | `scripts/resume-timer.sh` | 管理 15分钟自动同步 |
| 状态查看 | `scripts/resume-status.sh` | 显示进度面板 |
| 时间询问 | `scripts/resume-ask-time.sh` | 询问用户剩余时间，设置过期时间 |
| 时间查看 | `scripts/resume-time-remaining.sh` | 显示当前剩余时间 |
| 进度模板 | `templates/progress.yaml` | 进度追踪文件结构 |
| 配置文件 | `config/default-config.yaml` | 项目级配置 |

## 3. 详细设计

### 3.1 仓库结构（GitHub State Repo）

每个项目一个状态仓库，命名为 `{project-name}-state`：

```
{project-name}-state/
├── progress.yaml          # 进度追踪（核心文件）
├── .pending_log           # 待处理的 log 标记（定时器写，LLM 读取后删除）
├── environment/
│   ├── requirements.txt   # Python 依赖
│   ├── package.json       # Node.js 依赖（如果有）
│   ├── apt-packages.txt   # 系统包依赖
│   ├── env-vars.txt       # 关键环境变量
│   └── setup.sh           # 环境恢复脚本
├── workspace/             # 工作目录快照
│   ├── src/
│   ├── config/
│   └── ...
├── checkpoints/           # 检查点
│   ├── 001-initial.yaml
│   ├── 002-ocr-done.yaml
│   └── ...
└── .git/                  # Git 仓库
```

### 3.2 进度追踪文件（progress.yaml）

这是整个系统的核心，通过关键节点触发记录进度：

```yaml
# ========================================
# 会话信息
# ========================================
session:
  id: "2026-04-22-pm-1"      # 会话标识（日期-上午/下午-序号）
  started: "2026-04-22T14:00:00+08:00"
  expires_at: "2026-04-22T15:00:00+08:00"
  auto_save_interval: 900     # 秒（15分钟）
  last_saved: "2026-04-22T14:45:00+08:00"

# ========================================
# 当前位置（比 hybrid-workflow 更细）
# 当前位置（LLM随手更新，不强制格式）
position:
  project: "rag-tool-v3"
  project_desc: "煤矿防治水知识库工具v3"
  task: "PDF OCR 集成 - 步骤3/7"
  step: "3"
  total_steps: "7"
  note: "正在调试中文识别准确率"

# ========================================
# 关键节点记录（脚本触发，LLM写一句话）
# 触发条件：文件有变化、测试结果、安装依赖、用户决策
# 跳过条件：无变化的连续操作
# 1小时约 6-12 条
# ========================================
log:
  - "14:05 创建 test_ocr.py"
  - "14:12 中文识别测试 fail，准确率72%"
  - "14:20 切换到 paddleocr"
  - "14:28 中文测试 pass，准确率88%"
  - "14:35 开始写英文测试用例"

# ========================================
# 检查点列表（只保留已确认的）
# ========================================
checkpoints:
  - id: 47
    timestamp: "2026-04-21T17:55:00Z"
    description: "完成 OCR 配置，准备写测试"
    status: "confirmed"

  - id: 48
    timestamp: "2026-04-22T14:45:00+08:00"
    description: "中文测试全部通过"
    status: "pending_confirmation"

# ========================================
# 待办事项
# ========================================
todo:
  - "添加英文 PDF 测试用例"
  - "更新 README 文档"
```

### 3.3 命令设计

#### 核心命令

| 命令 | 功能 | 时机 |
|------|------|------|
| `resume-init <repo>` | 初始化项目状态仓库 | 新项目首次使用 |
| `resume-restore` | 从 GitHub 恢复上次状态 | 每次新会话开始 |
| `resume-save [message]` | 手动保存当前状态 | 关键步骤完成时 |
| `resume-checkpoint <desc>` | 创建确认检查点 | 阶段性成果完成时 |
| `resume-checkpoint-confirm <id>` | 确认检查点为 confirmed | 检查点创建后确认 |
| `resume-time-remaining` | 显示会话剩余时间 | 随时查看剩余时间 |
| `resume-ask-time` | 设置环境剩余时间 | init/restore 时、手动更新 |
| `resume-env` | 捕获当前环境依赖 | 安装新依赖后 |
| `resume-status` | 显示当前进度概览 | 随时查看 |
| `resume-timer start/stop` | 控制自动同步定时器 | 会话开始/结束时 |

#### Log 触发机制

**.pending_log 文件规范：**
- 位置：状态仓库根目录（`{state-dir}/.pending_log`）
- 写入者：定时器脚本（resume-timer.sh）
- 读取者：LLM（Agent）
- 内容：git diff --stat 的摘要
- 生命周期：写入 → LLM读取 → 删除

**定时器行为（每15分钟）：**
```
定时器同步 → git diff --cached → 有变化？
  ├─ 有 → 写 .pending_log（含变化摘要），git commit + push
  └─ 无 → 跳过
```

**LLM 读取时机：**
```
LLM 每次响应前 → 检查状态目录中的 .pending_log？
  ├─ 存在 → 读取内容，写一条简短 log 到 progress.yaml，删除 .pending_log
  └─ 不存在 → 不管
```

**恢复时处理：**
```
resume-restore 时 → 检查 .pending_log？
  ├─ 存在 → 说明上次会话结束时有未处理的变化，读取并写 log
  └─ 不存在 → 正常恢复
```

log 条目格式：`"HH:MM 简短描述"`，例如：
- `"14:05 创建 test_ocr.py"`
- `"14:12 中文识别测试 fail，准确率72%"`
- `"14:20 切换到 paddleocr"`

**记录触发规则：**
| 事件 | 动作 |
|------|------|
| 文件新建/修改 | 累积，下条LLM响应时记录 |
| 测试 pass/fail | 立即记录（测试结果是关键节点） |
| 安装新依赖 | 立即记录 |
| 用户输入决策 | 立即记录 |
| 无变化的连续操作 | 不记录 |

1小时预估 6-12 条 log 记录。

#### Agent 使用流程

**新项目初始化：**
```
用户：openclaw-resume 初始化，项目名 rag-tool-v3
Hermes：
  1. 创建 GitHub 仓库 rag-tool-v3-state（private）
  2. 初始化 progress.yaml
  3. 捕获当前环境 → environment/
  4. 推送初始状态到 GitHub
  5. 启动 15分钟定时器
```

**恢复会话：**
```
用户：openclaw-resume 恢复
Hermes：
  1. 从 GitHub 拉取最新状态
  2. 读取 progress.yaml → 显示上次进度
  3. 恢复工作文件到 workspace/
  4. 运行 setup.sh 恢复环境
  5. 启动 15分钟定时器
  6. 输出：你上次在做 rag-tool-v3，任务 PDF OCR 集成，步骤 3/7
  7. 读取 .pending_log（如果有），写一条 log 记录
```

**会话中自动同步（定时器触发）：**
```
定时器：每15分钟触发
Hermes：
  1. 读取当前 progress.yaml
  2. git add + commit + push
  3. 成功 → 更新 last_saved 时间
  4. 失败 → 记录错误，下次重试
```

**手动保存 + 确认检查点：**
```
用户：保存进度，检查点：OCR 测试通过
Hermes：
  1. 更新 progress.yaml（添加 log 条目）
  2. 创建检查点（pending_confirmation）
  3. 捕获环境变化
  4. 推送到 GitHub
  5. 调用 resume-checkpoint-confirm 确认 → status 改为 confirmed
```

**会话快结束时（检测到时间不足）：**
```
Agent（内部）：使用 resume-time-remaining 检测剩余 <5分钟
Hermes：
  1. 调用 resume-save 强制保存
  2. 调用 resume-checkpoint 创建紧急检查点
  3. 推送到 GitHub
  4. 提醒用户：时间快到了，已自动保存
```

### 3.4 环境捕获与恢复

#### 捕获策略

```bash
# env-capture.sh 执行的操作：

# 1. Python 依赖
pip freeze > environment/requirements.txt

# 2. Node.js 依赖（如果项目目录有 package.json）
[ -f package.json ] && cp package.json environment/

# 3. 系统包依赖（apt）
dpkg --get-selections | grep -v deinstall > environment/apt-packages.txt

# 4. 关键环境变量
env | grep -E '^(PATH|PYTHON|NODE|LANG)' > environment/env-vars.txt

# 5. 生成 setup.sh
cat > environment/setup.sh << 'SCRIPT'
#!/bin/bash
set -e
echo "=== 恢复环境 ==="

# 系统包
echo "安装系统依赖..."
apt-get update -qq
xargs -a apt-packages.txt apt-get install -y -qq 2>/dev/null || true

# Python
if [ -f requirements.txt ]; then
    echo "安装 Python 依赖..."
    pip install -r requirements.txt -q
fi

# Node.js
if [ -f package.json ]; then
    echo "安装 Node.js 依赖..."
    npm install --silent
fi

echo "=== 环境恢复完成 ==="
SCRIPT
chmod +x environment/setup.sh
```

#### 恢复策略

环境恢复在 `resume-restore.sh` 中实现：

```bash
# resume-restore.sh 中的环境恢复逻辑

# 1. 从 GitHub 拉取
git pull origin main

# 2. 检查环境文件完整性
for f in requirements.txt setup.sh apt-packages.txt; do
    [ -f "environment/$f" ] || log_warn "缺少 $f"
done

# 3. 执行 setup.sh（检测权限）
cd environment
if [ -f setup.sh ]; then
    log_info "执行环境恢复脚本..."
    if [ "$(id -u)" -eq 0 ]; then
        bash setup.sh
    else
        # 尝试 sudo，失败则跳过系统包安装
        sudo bash setup.sh 2>/dev/null || bash setup.sh 2>/dev/null || log_warn "环境恢复部分失败"
    fi
fi

# 4. 恢复工作文件
cd ..
cp -r workspace/* ~/workspace/ 2>/dev/null || true

echo "恢复完成"
```

### 3.5 自动同步定时器（resume-timer.sh）

```bash
# resume-timer.sh 核心逻辑

SYNC_INTERVAL=900  # 15分钟 = 900秒
PID_FILE="$HOME/.openclaw-resume/timer.pid"  # PID 文件位置
LOG_FILE="$HOME/.openclaw-resume/sync.log"   # 同步日志

start_timer() {
    local project_name="$1"
    local state_dir="$OPENCLAW_RESUME_BASE/$project_name"

    # 后台循环
    (
        while true; do
            sleep $SYNC_INTERVAL
            
            # 检查父进程是否还在
            [ ! -f "$PID_FILE" ] && break
            
            cd "$state_dir" || continue
            
            # 更新 last_saved
            sed -i "s/last_saved:.*/last_saved: \"$(date -Iseconds)\"/" progress.yaml
            
            # 同步工作文件（rsync --checksum）
            rsync -a --checksum --delete ... "$workspace_src/" "$workspace_dst/"
            
            # Git 操作
            git add -A
            if ! git diff --cached --quiet; then
                # 有变化，创建 .pending_log
                git diff --cached --stat | tail -1 > ".pending_log"
                git commit -m "auto-sync: $(date '+%Y-%m-%d %H:%M')"
                git push origin main || git pull --rebase origin main && git push origin main
            fi
        done
    ) &
    echo $! > "$PID_FILE"
}

stop_timer() {
    [ -f "$PID_FILE" ] && kill "$(cat "$PID_FILE")" 2>/dev/null && rm "$PID_FILE"
}

status_timer() {
    [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null && echo "运行中" || echo "未运行"
}
```

### 3.6 同步引擎（内嵌于各脚本）

同步逻辑分布在多个脚本中，不单独成文件：

- **resume-init.sh**：初始化时 git clone / git init + push
- **resume-restore.sh**：git pull origin main
- **resume-save.sh**：git add + commit + push
- **resume-timer.sh**：定时 git add + commit + push

**通用同步流程：**
```bash
# 同步到 GitHub
sync_to_github() {
    local state_dir="$1"
    local message="$2"
    
    cd "$state_dir"
    
    # 更新 last_saved
    sed -i "s/last_saved:.*/last_saved: \"$(date -Iseconds)\"/" progress.yaml
    
    # Git 操作
    git add -A
    if git diff --cached --quiet; then
        echo "没有变化，跳过同步"
        return 0
    fi
    
    git commit -m "$message"
    if ! git push origin main 2>/dev/null; then
        # 推送失败，尝试 rebase
        git pull --rebase origin main && git push origin main
    fi
}
```
```

## 4. 检查点系统

### 4.1 检查点类型

| 类型 | 触发条件 | 状态 |
|------|----------|------|
| 自动保存 | 每15分钟 | auto |
| 手动保存 | 用户触发 | manual |
| 阶段检查点 | 阶段性成果 | confirmed（需确认）|
| 紧急检查点 | 会话即将结束 | emergency |
| 环境检查点 | 安装新依赖后 | environment |

### 4.2 检查点生命周期

```
pending → confirmed → superseded
         ↓
      restored (被恢复时)
```

- **pending** — 刚创建，等待用户确认
- **confirmed** — 用户确认的稳定状态
- **superseded** — 被更新的检查点替代

### 4.3 冲突解决（一天多次使用）

规则：**只取最新的 confirmed 检查点，但提示未确认的检查点**

```
场景：
  上午 9:00  创建检查点 #48 (confirmed) - "OCR框架完成"
  上午 9:55  创建检查点 #49 (pending) - "测试用例写到一半"
  下午 2:00  创建检查点 #50 (pending) - "英文测试进行中"
  下午 3:00  开始新会话

恢复策略：
  → 从 GitHub 拉取
  → 读取 checkpoints/
  → 列出所有 pending 检查点（#49, #50）
  → #48 是最新的 confirmed，从这里恢复
  → #49, #50 的 changes 保留在 workspace/ 但不在 log 中
  → 提示用户：
    "⚠️ 发现 2 个未确认的检查点：
     #49: 测试用例写到一半
     #50: 英文测试进行中
     是否要从某个 pending 检查点恢复？"
```

**恢复优先级：**
1. 最新的 confirmed 检查点（默认）
2. 用户选择的 pending 检查点（手动指定）
3. 如果没有 confirmed 且用户未选择 → 从空项目开始

## 5. 安全设计

### 5.1 GitHub 认证

- 使用 **Personal Access Token (PAT)**
- PAT 存储在环境变量 `OPENCLAW_RESUME_PAT` 中
- **不写入** progress.yaml 或任何同步文件
- config.yaml 中只存 `github_user` 和 `repo_name`，不含 token

### 5.2 敏感文件排除

`.gitignore` 自动排除：
```
.env
*.key
*.pem
__pycache__/
node_modules/
.venv/
*.pyc
```

### 5.3 仓库可见性

- 状态仓库默认 **private**
- 包含工作代码和配置，不公开

## 6. 工作流集成

### 6.1 Agent 级别集成

Agent 的更新频率由"关键节点触发"机制控制：

**触发 log 记录的事件：**
- 文件有变化（通过 .pending_log 标记）
- 测试 pass/fail
- 安装新依赖
- 用户输入决策

**Agent 的职责：**
```
工具调用返回 → 有 .pending_log？
  ├─ 有 → 读取变化摘要，写一条简短 log（一行），删除标记
  └─ 无 → 不管

用户要求保存 / 阶段成果完成：
  → resume-checkpoint <描述>  （写检查点）

安装新依赖后：
  → resume-env  （捕获环境）
```

**不记录的情况：**
- 无变化的连续操作
- 只是读取/查看
- 纯对话

1小时约 6-12 条 log 记录。

### 6.2 时间感知机制

OpenClaw 在线试用环境是虚拟机级别限制（1小时后销毁），脚本无法检测实际剩余时间。改为**用户手动输入**机制。

**使用流程：**

```
会话开始（init 或 restore）时：
  Agent：⏱️ 当前环境还剩多少分钟？
  用户：55
  Agent：✅ 已设置 55 分钟后到期
```

**resume-ask-time 命令：**
```
用法：resume-ask-time [project-name]
功能：询问用户剩余时间，更新 progress.yaml 的 expires_at
触发：init 时、restore 时、用户手动调用
```

**Agent 自检逻辑：**

Agent 在每次响应时，读取 progress.yaml 的 session.expires_at，计算剩余时间：
```bash
expires_at=$(yaml_get "session.expires_at")
now=$(date +%s)
expire_epoch=$(date -d "$expires_at" +%s)
remaining_minutes=$((expire_epoch - now) / 60)

if [ $remaining_minutes -lt 5 ]; then
    # 触发紧急保存
    resume-save "时间即将到期"
    resume-checkpoint "紧急保存"
    # 提醒用户
fi
```

**紧急保存触发条件：**
- 剩余 < 5 分钟 → 强制保存 + 创建紧急检查点 + 提醒用户
- 剩余 < 2 分钟 → 保存 + 强烈提醒用户

**resume-time-remaining 命令（保留）：**
```
返回值：剩余分钟数（整数）
用法：remaining=$(resume-time-remaining)
      echo "还剩 ${remaining} 分钟"
```

### 6.3 定时器行为

```
会话开始：
  resume-timer start
  → 后台每15分钟自动 sync

会话结束（主动）：
  resume-timer stop
  resume-save "会话结束，最后保存"
  resume-checkpoint "会话结束检查点"

会话结束（被动/超时）：
  定时器会自动在最后一次15分钟时保存
  如果刚好在15分钟窗口内超时，可能丢失最多15分钟工作
  → 建议：Agent 在检测到时间不足时主动保存
```

### 7. 性能优化

**rsync 同步优化：**
```bash
# 使用 --checksum 只同步变化的文件
rsync -a --checksum --delete \
  --exclude='node_modules' \
  --exclude='__pycache__' \
  --exclude='.venv' \
  --exclude='.git' \
  --exclude='*.pyc' \
  "$workspace_src/" "$workspace_dst/"
```

**env-capture 触发策略：**
- 不要在每次 `resume-save` 时都执行 `pip freeze`
- 只在以下情况执行：
  1. `resume-init` 时
  2. 用户主动调用 `resume-env` 时
  3. 检测到 `pip install` 或 `npm install` 后（通过 .pending_log）

## 8. 限制与已知问题

1. **定时器粒度** — 最多丢失15分钟工作（定时器间隔）
2. **大文件同步** — GitHub 有100MB文件限制，大模型文件需用 Git LFS
3. **环境差异** — 不同试用环境的系统版本可能不同，setup.sh 可能失败
4. **网络依赖** — 同步需要网络，离线时无法同步
5. **并发冲突** — 如果两个会话同时运行，后push的会覆盖前一个

## 9. 验收标准

1. 新项目初始化 < 2分钟
2. 从 GitHub 恢复状态 < 5分钟（含环境恢复）
3. 自动同步成功率 > 95%
4. 丢失工作 < 15分钟（定时器间隔）
5. 检查点恢复成功率 100%（confirmed 状态）

---

## 附录：目录结构总览

```
openclaw-resume/
├── SKILL.md                    # Skill 定义
├── DESIGN.md                   # 本文档
├── ROADMAP.md                  # 里程碑路线图
├── README.md                   # 使用说明
├── .gitignore                  # Git 排除文件
├── scripts/
│   ├── core.sh                 # 核心库（颜色输出、YAML操作、工具函数）
│   ├── resume-init.sh          # 初始化项目
│   ├── resume-restore.sh       # 从 GitHub 恢复状态
│   ├── resume-save.sh          # 手动保存
│   ├── resume-checkpoint.sh    # 检查点管理（创建、确认）
│   ├── env-capture.sh          # 环境依赖捕获 + setup.sh 生成
│   ├── resume-status.sh        # 状态面板
│   ├── resume-ask-time.sh      # 询问并设置环境剩余时间
│   ├── resume-time-remaining.sh # 显示剩余时间
│   └── resume-timer.sh         # 15分钟自动同步定时器
├── templates/
│   └── progress.yaml           # 进度文件模板
├── config/
│   └── default-config.yaml     # 默认配置
└── examples/
    └── demo-flow.md            # 使用示例
```

### GitHub 状态仓库结构（每个项目一个）

```
{project-name}-state/
├── progress.yaml               # 进度追踪（核心文件）
├── .pending_log                # 待处理的 log 标记（定时器写，LLM读取后删除）
├── environment/
│   ├── requirements.txt        # Python 依赖
│   ├── package.json            # Node.js 依赖（如果有）
│   ├── apt-packages.txt        # 系统包依赖
│   ├── env-vars.txt            # 关键环境变量
│   └── setup.sh                # 环境恢复脚本
├── workspace/                  # 工作目录快照
│   └── ...
├── checkpoints/                # 检查点
│   ├── 001-xxx.yaml
│   ├── 002-xxx.yaml
│   └── ...
└── .git/                       # Git 仓库
```
