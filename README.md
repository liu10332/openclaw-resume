# openclaw-resume

OpenClaw 限时试用环境（1小时）的跨会话续接工具。

## 问题

在线 OpenClaw 试用每次限时1小时，虚拟环境到期自动销毁，所有数据丢失。下次使用必须从零开始。

## 解决方案

通过 GitHub 仓库同步状态，实现：
- **进度追踪** — 关键节点触发记录（1小时约6-12条）
- **自动同步** — 每15分钟自动 push + 随时手动保存
- **环境恢复** — pip/npm/apt 依赖自动捕获和恢复
- **检查点续接** — 只取已确认的检查点，避免中间状态污染

## 快速开始

### 1. 配置环境变量

```bash
export OPENCLAW_RESUME_PAT="ghp_xxxxxxxxxxxx"      # GitHub PAT
export OPENCLAW_RESUME_USER="your-github-username"  # GitHub 用户名
```

### 2. 加载 Skill

在 OpenClaw 中加载此 Skill，所有命令自动可用。

### 3. 使用流程

**首次（新项目）：**
```
resume-init my-project       # 初始化（创建 GitHub 仓库 + 初始状态）
# ... 正常工作 ...
resume-checkpoint "完成XX"   # 关键节点手动保存
resume-save "准备休息"       # 随时手动保存
```

**后续（恢复）：**
```
resume-restore my-project    # 自动拉取 + 恢复文件 + 恢复环境 + 启动定时器
resume-status                # 查看进度
# ... 继续工作 ...
```

**结束时：**
```
resume-timer stop            # 停止定时器（自动做最后一次保存）
```

## 命令一览

| 命令 | 功能 |
|------|------|
| `resume-init <name>` | 初始化项目状态仓库 |
| `resume-restore [name]` | 从 GitHub 恢复上次状态 |
| `resume-save [msg]` | 手动保存当前状态 |
| `resume-checkpoint <desc>` | 创建检查点（待确认） |
| `resume-checkpoint-confirm <id>` | 确认检查点 |
| `resume-env` | 捕获当前环境依赖 |
| `resume-status` | 显示进度面板 |
| `resume-timer start/stop/status` | 管理自动同步定时器 |

## 目录结构

```
~/.openclaw-resume/{project}/     # 本地状态目录
├── progress.yaml                  # 进度追踪（核心）
├── environment/                   # 环境依赖
│   ├── requirements.txt
│   ├── apt-packages.txt
│   └── setup.sh
├── workspace/                     # 工作文件快照
├── checkpoints/                   # 检查点
└── .git/                          # → GitHub 同步
```

## 工作原理

```
┌─────────────┐    15min auto     ┌──────────────┐
│ OpenClaw    │ ──────────────▶  │ GitHub Repo  │
│ Environment │    manual save   │ (private)    │
│             │ ◀──────────────  │              │
│  workspace/ │    git pull      │  workspace/  │
│  progress   │                  │  progress    │
│  env deps   │                  │  checkpoints │
└─────────────┘                  └──────────────┘
```

1. 工作中：每15分钟自动同步 + 手动保存
2. 环境销毁：数据安全在 GitHub
3. 新会话：拉取 → 恢复文件 → 恢复环境 → 继续

## 安全

- PAT 仅存储在环境变量，不同步到 GitHub
- 状态仓库默认 private
- .gitignore 自动排除 .env、密钥等敏感文件

## 限制

- 最多丢失15分钟工作（定时器间隔内超时）
- GitHub 有100MB文件限制（大文件用 Git LFS）
- 不同试用环境系统版本可能不同，setup.sh 可能需调整

## 设计文档

详见 [DESIGN.md](DESIGN.md)
