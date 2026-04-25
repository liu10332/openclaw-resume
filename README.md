# openclaw-resume

OpenClaw 限时试用环境（1小时）的跨会话续接工具。通过 GitHub 同步状态，实现工作进度、代码和环境依赖的自动保存与恢复。

## 快速开始（任意机器，无需 OpenClaw）

### 一键初始化

```bash
# 下载脚本（只需一次）
curl -O https://raw.githubusercontent.com/liu10332/openclaw-resume/master/quick-init.sh
chmod +x quick-init.sh
```

### 三步使用

```bash
# 1. 初始化项目（创建 GitHub 仓库 + 同步文件）
bash quick-init.sh init my-project ./your-code

# 2. 手动添加额外文件（可选）
bash quick-init.sh add my-project ./config.yaml ./docs/

# 3. 推送到 GitHub
bash quick-init.sh push my-project
```

### 一步完成

```bash
bash quick-init.sh init my-project ./code && bash quick-init.sh push my-project
```

### 查看状态

```bash
bash quick-init.sh status my-project
bash quick-init.sh status              # 列出所有项目
```

## 在 OpenClaw 试用环境恢复

```bash
# 设置认证
export OPENCLAW_RESUME_PAT="ghp_你的token"
export OPENCLAW_RESUME_USER="你的github用户名"

# 克隆本项目
git clone https://ghp_你的token@github.com/liu10332/openclaw-resume.git
cd openclaw-resume

# 一键恢复
source scripts/resume-restore.sh
resume-restore my-project
```

恢复后自动完成：
- ✅ 从 GitHub 拉取最新状态
- ✅ 恢复工作文件
- ✅ 恢复 pip/apt/npm 环境依赖
- ✅ 启动 15 分钟自动同步定时器

## 工作中使用

```bash
# 手动保存
bash quick-init.sh push my-project

# 或在 OpenClaw 环境中
resume-save "正在调试 API"
resume-checkpoint "完成用户登录模块"
resume-status
resume-timer start my-project
```

## 完整流程图

```
本地机器                          GitHub                         试用环境
────────                        ────────                       ────────
quick-init.sh init ────────▶ 创建仓库
    │
手动添加文件
quick-init.sh add
    │
quick-init.sh push ────────▶ 推送代码+环境
    │                              │
工作中...                           │
quick-init.sh push ────────▶ 同步更新
    │                              │
（换电脑/试用环境）                   │
                              ◀────┤
                               resume-restore
                                    │
                              恢复文件+环境+定时器
                                    │
                              resume-save ──────▶ ...
```

## add 命令支持

```bash
# 单个文件
bash quick-init.sh add my-project ./README.md

# 多个文件
bash quick-init.sh add my-project ./a.py ./b.py

# 整个目录
bash quick-init.sh add my-project ./docs/

# 混合
bash quick-init.sh add my-project ./config.yaml ./src/ ./README.md
```

路径规则：
- 工作目录下的文件 → 保留相对路径（`./src/main.py` → `workspace/src/main.py`）
- 外部文件 → 只复制文件名（`/tmp/xxx.py` → `workspace/xxx.py`）

## 命令一览

| 命令 | 功能 |
|------|------|
| `quick-init.sh init <name> [目录]` | 初始化项目（不推送） |
| `quick-init.sh add <name> <文件...>` | 添加额外文件 |
| `quick-init.sh push <name>` | 推送到 GitHub |
| `quick-init.sh status [name]` | 查看状态 |
| `resume-init <name>` | OpenClaw 环境初始化 |
| `resume-restore <name>` | OpenClaw 环境恢复 |
| `resume-save [msg]` | 手动保存 |
| `resume-checkpoint <desc>` | 创建检查点 |
| `resume-env [name]` | 重新捕获环境 |
| `env-restore [name]` | 独立恢复环境 |
| `resume-status` | 状态面板 |
| `resume-timer start/stop` | 自动同步定时器 |
| `resume-urgent-save` | 紧急保存 |

## 目录结构

```
~/.openclaw-resume/<项目名>/
├── .git/                    # → GitHub 同步
├── .resume-config           # 项目配置（PAT、路径等）
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

- PAT 仅存储在本地 `.resume-config`（chmod 600），不同步到 GitHub
- 状态仓库默认 private
- `.gitignore` 自动排除 .env、密钥等敏感文件

## 限制

- GitHub 有 100MB 文件限制（大文件用 Git LFS）
- 不同试用环境系统版本可能不同，setup.sh 可能需调整
- 定时器间隔（15分钟）内的工作可能丢失

## 测试

```bash
bash tests/test-e2e.sh
# 33 项测试全部通过 ✅
```

## 文档

- [AGENT_GUIDE.md](AGENT_GUIDE.md) — Agent 使用指南
- [SKILL.md](SKILL.md) — 技能定义
- [DESIGN.md](DESIGN.md) — 设计文档
- [ROADMAP.md](ROADMAP.md) — 路线图
- [PROGRESS.md](PROGRESS.md) — 进度日志
