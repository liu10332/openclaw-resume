# openclaw-resume

OpenClaw 限时试用环境（1小时）的跨会话续接工具。通过 GitHub 同步状态，实现工作进度、代码和环境依赖的自动保存与恢复。

## 适用场景

- **OpenClaw 试用环境**（限时 1 小时）：环境销毁前自动保存，下次恢复
- **本地开发机器**：手动保存工作进度，在不同机器间同步

---

## 前置条件

1. **GitHub 个人访问令牌 (PAT)**：[创建地址](https://github.com/settings/tokens)，需要 `repo` 权限
2. **Git** 已安装
3. **bash** 环境（Linux / macOS / WSL）

设置环境变量：

```bash
export OPENCLAW_RESUME_PAT="ghp_你的token"    # 用于访问私有项目状态仓库
export OPENCLAW_RESUME_USER="你的github用户名"
```

> **注意**：本仓库（openclaw-resume）已公开，下载技能不需要认证。PAT 仅用于访问你的私有项目状态仓库。

---

## 方式 1：quick-init.sh（推荐，最简单）

无需克隆本仓库，一条命令搞定。

```bash
# 下载脚本
curl -O https://raw.githubusercontent.com/liu10332/openclaw-resume/main/quick-init.sh
chmod +x quick-init.sh

# 初始化项目（创建 GitHub 仓库 + 同步文件，不推送）
bash quick-init.sh init my-project ./your-code

# 推送到 GitHub
bash quick-init.sh push my-project
```

之后在另一台机器或新环境恢复：

```bash
# 下载本仓库（公开仓库，无需认证）
git clone https://github.com/liu10332/openclaw-resume.git
cd openclaw-resume

# 加载脚本
source scripts/core.sh
source scripts/resume-restore.sh

# 恢复项目
resume-restore my-project
```

---

## 方式 2：完整脚本（功能更全）

适合需要检查点、环境捕获、定时自动同步等高级功能的场景。

```bash
# 克隆本仓库（公开仓库，无需认证）
git clone https://github.com/liu10332/openclaw-resume.git
cd openclaw-resume
```

### 首次使用（初始化新项目）

```bash
# 加载核心脚本
source scripts/core.sh
source scripts/resume-init.sh

# 初始化（会创建 GitHub 仓库、捕获环境、询问剩余时间）
resume-init my-project
```

初始化后自动完成：
- ✅ 创建 `{project-name}-state` 私有仓库
- ✅ 同步工作文件到仓库
- ✅ 捕获 pip/apt/npm 环境依赖
- ✅ 生成环境恢复脚本 setup.sh
- ✅ 启动 15 分钟自动同步定时器

### 继续工作

```bash
# 随时保存
source scripts/resume-save.sh
resume-save "正在调试 API"

# 关键节点创建检查点
source scripts/resume-checkpoint.sh
resume-checkpoint "完成用户登录模块"

# 查看状态
source scripts/resume-status.sh
resume-status

# 列出所有项目
source scripts/resume-list.sh
resume-list
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
- ✅ 执行 setup.sh 恢复环境依赖
- ✅ 启动 15 分钟自动同步定时器
- ✅ 显示上次进度

### 会话结束

```bash
resume-save "会话结束"
source scripts/resume-timer.sh
resume-timer stop
```

---

## 完整流程图

```
本地机器                              GitHub                         另一台机器
────────                            ────────                       ────────
resume-init my-project ─────────▶ 创建 my-project-state 仓库
    │
工作中...
resume-save / checkpoint ──────▶ 推送代码+环境+进度
    │                                    │
（换机器 / 新环境）                        │
                                      ◀──┤
                                   resume-restore
                                        │
                                  恢复文件+环境+定时器
                                        │
                                  resume-save ──────▶ ...
```

---

## 命令一览

### 项目管理

| 命令 | 功能 | 参数 |
|------|------|------|
| `resume-init` | 初始化新项目 | `<project-name>` |
| `resume-restore` | 恢复上次会话 | `[project-name]` |
| `resume-list` | 列出所有项目 | `[-a]` 详细模式 |
| `resume-delete` | 删除项目 | `<name> [--force]` |
| `resume-status` | 查看状态面板 | `[project-name]` |

### 工作保存

| 命令 | 功能 | 参数 |
|------|------|------|
| `resume-save` | 保存当前状态 | `[message]` |
| `resume-checkpoint` | 创建检查点 | `<description>` |

### 环境管理

| 命令 | 功能 | 参数 |
|------|------|------|
| `resume-env` | 捕获环境依赖 | `[project-name]` |
| `env-restore` | 恢复环境依赖 | `[project-name]` |

### 定时器

| 命令 | 功能 | 参数 |
|------|------|------|
| `resume-timer start` | 启动自动同步（每 15 分钟） | `[project-name]` |
| `resume-timer stop` | 停止自动同步 | — |
| `resume-timer status` | 查看定时器状态 | — |

### 时间管理

| 命令 | 功能 | 参数 |
|------|------|------|
| `resume-time-remaining` | 查看剩余分钟数 | `[project-name]` |
| `resume-ask-time` | 设置剩余时间 | `[project-name]` |

### 其他

| 命令 | 功能 | 参数 |
|------|------|------|
| `resume-urgent-save` | 紧急保存（<5 分钟时触发） | `[project-name]` |
| `quick-init.sh init` | 快捷初始化（不推送） | `<name> [dir] [PAT] [user]` |
| `quick-init.sh add` | 添加额外文件 | `<name> <files...>` |
| `quick-init.sh push` | 推送到 GitHub | `<name> [PAT] [user]` |
| `quick-init.sh status` | 查看状态 | `[name]` |

---

## 使用示例

### 示例 1：在本地机器保存工作

```bash
# 设置环境变量
export OPENCLAW_RESUME_PAT="ghp_xxxx"
export OPENCLAW_RESUME_USER="myname"

# 下载 quick-init.sh
curl -O https://raw.githubusercontent.com/liu10332/openclaw-resume/main/quick-init.sh
chmod +x quick-init.sh

# 把 my-project 目录推到 GitHub
bash quick-init.sh init my-project ./my-project
bash quick-init.sh push my-project

# 工作一段时间后，再次保存
bash quick-init.sh push my-project
```

### 示例 2：在新环境恢复

```bash
export OPENCLAW_RESUME_PAT="ghp_xxxx"
export OPENCLAW_RESUME_USER="myname"

git clone https://ghp_xxxx@github.com/liu10332/openclaw-resume.git
cd openclaw-resume

source scripts/core.sh
source scripts/resume-restore.sh
resume-restore my-project

# 恢复后继续工作，定时器自动同步
# 手动保存
source scripts/resume-save.sh
resume-save "继续开发"
```

### 示例 3：使用检查点

```bash
source scripts/core.sh
source scripts/resume-init.sh
resume-init my-project

# 完成一个阶段后
source scripts/resume-checkpoint.sh
resume-checkpoint "完成数据库设计"

# 完成下一个阶段
resume-checkpoint "完成 API 接口"

# 查看所有检查点
source scripts/resume-status.sh
resume-status
```

### 示例 4：OpenClaw 新环境一键恢复

如果项目初始化时已自动生成 `bootstrap.sh`：

```bash
export OPENCLAW_RESUME_PAT="ghp_xxxx"
export OPENCLAW_RESUME_USER="myname"
bash bootstrap.sh
```

---

## 目录结构

### 本仓库（openclaw-resume）

```
openclaw-resume/
├── quick-init.sh                    # 快捷初始化脚本
├── scripts/
│   ├── core.sh                      # 核心库（共享函数）
│   ├── resume-init.sh               # 初始化项目
│   ├── resume-restore.sh            # 恢复会话
│   ├── resume-save.sh               # 手动保存
│   ├── resume-checkpoint.sh         # 检查点管理
│   ├── resume-status.sh             # 状态面板
│   ├── resume-list.sh               # 列出项目
│   ├── resume-delete.sh             # 删除项目
│   ├── env-capture.sh               # 环境捕获
│   ├── env-restore.sh               # 环境恢复
│   ├── resume-timer.sh              # 自动同步定时器
│   ├── resume-time-remaining.sh     # 剩余时间
│   ├── resume-ask-time.sh           # 设置时间
│   ├── resume-urgent-save.sh        # 紧急保存
│   └── resume-bootstrap-gen.sh      # 生成 bootstrap.sh
├── templates/
│   └── progress.yaml                # 进度文件模板
├── config/
│   └── default-config.yaml          # 默认配置
├── tests/
│   └── test-e2e.sh                  # 端到端测试（59 项）
├── SKILL.md                         # OpenClaw 技能定义
├── AGENT_GUIDE.md                   # Agent 使用指南
├── DESIGN.md                        # 设计文档
├── ROADMAP.md                       # 路线图
└── PROGRESS.md                      # 进度日志
```

### 项目状态目录（~/.openclaw-resume/<项目名>/）

```
~/.openclaw-resume/<项目名>/
├── .git/                    # → GitHub 同步
├── bootstrap.sh             # 新环境一键恢复脚本（自动生成）
├── progress.yaml            # 进度追踪
├── .pending_log             # 待处理的 log 标记
├── environment/             # 环境依赖
│   ├── requirements.txt     #   Python 依赖
│   ├── apt-packages.txt     #   系统包
│   ├── npm-global.json      #   npm 全局包
│   ├── package.json         #   Node.js 项目配置
│   ├── env-vars.txt         #   环境变量快照
│   └── setup.sh             #   环境恢复脚本
├── workspace/               # 工作文件快照
│   └── ...
└── checkpoints/             # 检查点
    ├── 001-xxx.yaml
    └── 002-xxx.yaml
```

---

## 安全

- PAT 仅通过环境变量传递，不写入磁盘
- 状态仓库默认 private
- `.gitignore` 自动排除 .env、密钥等敏感文件

## 限制

- GitHub 有 100MB 文件限制（大文件用 Git LFS）
- 不同环境的系统版本可能不同，setup.sh 可能需调整
- 定时器间隔（15 分钟）内的工作可能丢失

## 测试

```bash
bash tests/test-e2e.sh
# 59 项测试全部通过 ✅
```

## License

MIT
