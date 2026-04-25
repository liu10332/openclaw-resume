# openclaw-resume

OpenClaw 限时试用环境（1小时）的跨会话续接工具。通过 GitHub 同步状态，实现工作进度、代码和环境依赖的自动保存与恢复。

## 一键安装

```bash
# 从 GitHub 安装（推荐）
curl -sL https://raw.githubusercontent.com/liu10332/openclaw-resume/main/install.sh | bash

# 或 clone 后本地安装
git clone https://github.com/liu10332/openclaw-resume.git
cd openclaw-resume && bash install.sh
```

安装后在任意目录直接使用 `resume` 命令。

## 快速开始

```bash
# 1. 设置认证（每次新会话）
export OPENCLAW_RESUME_PAT="ghp_你的token"
export OPENCLAW_RESUME_USER="你的github用户名"

# 2. 初始化项目
resume init my-project ./your-code

# 3. 正常工作... 定时器自动每 15 分钟同步

# 4. 关键节点保存
resume checkpoint "完成用户登录模块"
resume save "调试中，暂时保存"

# 5. 下次会话恢复
resume restore my-project
```

## 命令一览

### 项目管理

| 命令 | 功能 |
|------|------|
| `resume init <name> [dir]` | 初始化新项目 |
| `resume restore [name]` | 恢复上次会话 |
| `resume list [-a]` | 列出所有项目 |
| `resume delete <name> [--force]` | 删除项目 |
| `resume status [name]` | 查看状态面板 |

### 工作保存

| 命令 | 功能 |
|------|------|
| `resume save [message]` | 保存当前状态 |
| `resume checkpoint <desc>` | 创建检查点 |
| `resume diff` | 显示上次保存后的变化 |

### 环境管理

| 命令 | 功能 |
|------|------|
| `resume env [name]` | 捕获环境依赖 |
| `resume env-restore [name]` | 恢复环境依赖 |

### 定时器

| 命令 | 功能 |
|------|------|
| `resume timer start [name]` | 启动自动同步（每 15 分钟） |
| `resume timer stop` | 停止自动同步 |
| `resume timer status` | 查看定时器状态 |

### 时间管理

| 命令 | 功能 |
|------|------|
| `resume time [name]` | 查看剩余时间 |
| `resume ask-time [name]` | 设置剩余时间 |

### 其他

| 命令 | 功能 |
|------|------|
| `resume version` | 查看版本 |
| `resume help` | 查看帮助 |
| `resume uninstall` | 卸载工具 |

## 完整流程图

```
本地机器                              GitHub                         试用环境
────────                            ────────                       ────────
resume init my-project ────────▶ 创建 my-project-state 仓库
    │
工作中...
resume save / checkpoint ──────▶ 推送代码+环境+进度
    │                                    │
（换电脑/试用环境）                         │
                                      ◀──┤
                                   resume restore
                                        │
                                  恢复文件+环境+定时器
                                        │
                                  resume save ──────▶ ...
```

## resume list 输出示例

```
  项目名               最后保存         当前任务               检查点     定时器
  ──────────────────── ────────────── ──────────────────── ────────── ────────
  my-project           14:30          调试 API 接口          3          ✓
  rag-tool             09:15          —                      0          ✗

  共 2 个项目 | 1 个定时器运行中
```

## 从 quick-init.sh 迁移

如果你之前使用 `quick-init.sh`，它仍然可用：

```bash
bash quick-init.sh init my-project ./code
bash quick-init.sh push my-project
```

但推荐使用新的 `resume` 命令，体验更好。

## 目录结构

```
~/.openclaw-resume/
├── bin/                       # 安装文件（resume 命令）
│   ├── resume                 #   统一入口
│   └── scripts/               #   核心脚本
├── <项目名>/                   # 项目状态目录
│   ├── .git/                  #   → GitHub 同步
│   ├── progress.yaml          #   进度追踪
│   ├── environment/           #   环境依赖
│   │   ├── requirements.txt   #     Python
│   │   ├── apt-packages.txt   #     系统包
│   │   ├── npm-global.json    #     npm 全局
│   │   ├── package.json       #     Node.js 项目
│   │   ├── env-vars.txt       #     环境变量
│   │   └── setup.sh           #     恢复脚本
│   ├── workspace/             #   工作文件快照
│   └── checkpoints/           #   检查点
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

## 从源码安装

```bash
git clone https://github.com/liu10332/openclaw-resume.git
cd openclaw-resume
bash install.sh          # 安装到 ~/.openclaw-resume
bash tests/test-e2e.sh   # 运行测试
```

## 文档

- [AGENT_GUIDE.md](AGENT_GUIDE.md) — Agent 使用指南
- [SKILL.md](SKILL.md) — 技能定义
- [DESIGN.md](DESIGN.md) — 设计文档
- [ROADMAP.md](ROADMAP.md) — 路线图
- [PROGRESS.md](PROGRESS.md) — 进度日志

## License

MIT
