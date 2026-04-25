# openclaw-resume

OpenClaw 限时试用环境（1小时）的跨会话续接工具。通过 GitHub 同步状态，实现工作进度、代码和环境依赖的自动保存与恢复。

## 快速开始

### 方式 1：quick-init.sh（任意机器，无需 OpenClaw）

```bash
curl -O https://raw.githubusercontent.com/liu10332/openclaw-resume/main/quick-init.sh
chmod +x quick-init.sh

# 初始化 + 推送
bash quick-init.sh init my-project ./code && bash quick-init.sh push my-project
```

### 方式 2：OpenClaw 环境内使用

```bash
# 设置认证
export OPENCLAW_RESUME_PAT="ghp_你的token"
export OPENCLAW_RESUME_USER="你的github用户名"

# 克隆本项目
git clone https://你的token@github.com/liu10332/openclaw-resume.git
cd openclaw-resume

# 初始化项目
source scripts/core.sh
source scripts/resume-init.sh
resume-init my-project
```

### 恢复上次会话

```bash
source scripts/core.sh
source scripts/resume-restore.sh
resume-restore my-project
```

恢复后自动完成：
- ✅ 从 GitHub 拉取最新状态
- ✅ 恢复工作文件
- ✅ 恢复 pip/apt/npm 环境依赖
- ✅ 启动 15 分钟自动同步定时器

## 命令一览

### 项目管理

| 命令 | 功能 |
|------|------|
| `resume-init <name>` | 初始化新项目 |
| `resume-restore [name]` | 恢复上次会话 |
| `resume-list [-a]` | 列出所有项目 |
| `resume-delete <name> [--force]` | 删除项目 |
| `resume-status [name]` | 查看状态面板 |

### 工作保存

| 命令 | 功能 |
|------|------|
| `resume-save [message]` | 保存当前状态 |
| `resume-checkpoint <desc>` | 创建检查点 |

### 环境管理

| 命令 | 功能 |
|------|------|
| `resume-env [name]` | 捕获环境依赖 |
| `env-restore [name]` | 恢复环境依赖 |

### 定时器

| 命令 | 功能 |
|------|------|
| `resume-timer start [name]` | 启动自动同步（每 15 分钟） |
| `resume-timer stop` | 停止自动同步 |
| `resume-timer status` | 查看定时器状态 |

### 时间管理

| 命令 | 功能 |
|------|------|
| `resume-time-remaining [name]` | 查看剩余时间 |
| `resume-ask-time [name]` | 设置剩余时间 |

### 其他

| 命令 | 功能 |
|------|------|
| `resume-urgent-save [name]` | 紧急保存 |
| `quick-init.sh init/add/push/status` | 快捷初始化流程 |

## 完整流程图

```
本地机器                              GitHub                         试用环境
────────                            ────────                       ────────
quick-init.sh init ─────────────▶ 创建仓库
    │
手动添加文件 + push ────────────▶ 推送代码+环境
    │                                    │
工作中...                                 │
quick-init.sh push ────────────▶ 同步更新
    │                                    │
（换电脑/试用环境）                         │
                                      ◀──┤
                                   resume-restore
                                        │
                                  恢复文件+环境+定时器
                                        │
                                  resume-save ──────▶ ...
```

## 目录结构

```
~/.openclaw-resume/<项目名>/
├── .git/                    # → GitHub 同步
├── progress.yaml            # 进度追踪
├── environment/             # 环境依赖
│   ├── requirements.txt     #   Python
│   ├── apt-packages.txt     #   系统包
│   ├── npm-global.json      #   npm 全局
│   ├── package.json         #   Node.js 项目
│   ├── env-vars.txt         #   环境变量
│   └── setup.sh             #   恢复脚本
├── workspace/               # 工作文件快照
└── checkpoints/             # 检查点
```

## 安全

- PAT 仅通过环境变量传递，不写入磁盘
- 状态仓库默认 private
- `.gitignore` 自动排除 .env、密钥等敏感文件

## 限制

- GitHub 有 100MB 文件限制（大文件用 Git LFS）
- 不同试用环境系统版本可能不同，setup.sh 可能需调整
- 定时器间隔（15分钟）内的工作可能丢失

## 测试

```bash
bash tests/test-e2e.sh
# 54 项测试全部通过 ✅
```

## 文档

- [AGENT_GUIDE.md](AGENT_GUIDE.md) — Agent 使用指南
- [SKILL.md](SKILL.md) — 技能定义
- [DESIGN.md](DESIGN.md) — 设计文档
- [ROADMAP.md](ROADMAP.md) — 路线图
- [PROGRESS.md](PROGRESS.md) — 进度日志

## License

MIT
