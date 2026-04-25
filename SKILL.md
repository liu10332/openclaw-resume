---
name: openclaw-resume
description: "OpenClaw 限时试用环境跨会话续接工具 — 自动同步状态到 GitHub，恢复上次进度、代码和环境依赖。"
version: 0.2.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [workflow, persistence, session-management, github]
    related_skills: [hybrid-workflow]
---

# openclaw-resume

OpenClaw 限时试用环境（1小时）的跨会话续接工具。

## 问题

在线 OpenClaw 试用每次限时1小时，环境销毁后所有数据丢失。需要一套工具让下次试用能接续上次任务。本地开发时也希望能跨机器同步工作进度。

## 解决方案

通过 GitHub 仓库同步状态，实现：
- **进度追踪** — 关键节点触发记录（1小时约6-12条）
- **自动同步** — 每15分钟自动 push + 随时手动保存
- **环境恢复** — pip/npm/apt 依赖自动捕获和恢复
- **检查点续接** — 只取已确认的检查点，避免中间状态污染
- **一键恢复** — 新环境运行 bootstrap.sh 自动安装技能并恢复

## 前置条件

1. GitHub 个人访问令牌 (PAT)：[创建地址](https://github.com/settings/tokens)，需要 `repo` 权限
2. Git 已安装
3. bash 环境

```bash
export OPENCLAW_RESUME_PAT="ghp_xxxxxxxxxxxx"
export OPENCLAW_RESUME_USER="your-github-username"
```

## 快速开始

### 最简方式（quick-init.sh）

```bash
curl -O https://raw.githubusercontent.com/liu10332/openclaw-resume/main/quick-init.sh
chmod +x quick-init.sh

# 保存项目到 GitHub
bash quick-init.sh init my-project ./your-code
bash quick-init.sh push my-project

# 在另一台机器恢复
git clone https://你的token@github.com/liu10332/openclaw-resume.git
cd openclaw-resume
source scripts/core.sh
source scripts/resume-restore.sh
resume-restore my-project
```

### 完整方式（检查点 + 定时器）

```bash
git clone https://你的token@github.com/liu10332/openclaw-resume.git
cd openclaw-resume

source scripts/core.sh
source scripts/resume-init.sh
resume-init my-project
```

## 命令

所有命令都需要先 `source scripts/core.sh`，然后按需 source 对应脚本。

### 初始化新项目

```bash
source scripts/resume-init.sh
resume-init <project-name>
```

- 创建 GitHub 仓库 `{project-name}-state`
- 同步工作文件
- 捕获 pip/apt/npm 环境依赖
- 生成 setup.sh 环境恢复脚本
- 询问剩余时间，设置过期时间
- 启动 15 分钟自动同步定时器
- 在状态仓库中生成 bootstrap.sh（供新环境一键恢复）

### 恢复上次会话

```bash
source scripts/resume-restore.sh
resume-restore [project-name]
```

- 从 GitHub 拉取最新状态
- 显示上次进度（项目、任务、步骤、备注）
- 恢复工作文件
- 执行 setup.sh 恢复环境
- 启动自动同步定时器

### 保存当前状态

```bash
source scripts/resume-save.sh
resume-save [message]
```

- 同步工作文件到状态目录
- 更新 progress.yaml
- git commit + push

### 创建检查点

```bash
source scripts/resume-checkpoint.sh
resume-checkpoint <description>
```

- 创建 pending 检查点（含文件快照、git commit hash）
- 推送到 GitHub

### 列出所有项目

```bash
source scripts/resume-list.sh
resume-list [-a]
```

- 显示项目名、最后保存时间、当前任务、检查点数、定时器状态
- `-a` 显示详细信息

### 删除项目

```bash
source scripts/resume-delete.sh
resume-delete <project-name> [--force]
```

- 显示项目摘要
- 二次确认（`--force` 跳过）
- 可选删除 GitHub 仓库
- 停止关联的定时器

### 查看状态

```bash
source scripts/resume-status.sh
resume-status [project-name]
```

### 捕获 / 恢复环境

```bash
source scripts/env-capture.sh
resume-env [project-name]

source scripts/env-restore.sh
env-restore [project-name]
```

### 定时器

```bash
source scripts/resume-timer.sh
resume-timer start [project-name]   # 启动（每 15 分钟自动同步）
resume-timer stop                   # 停止
resume-timer status                 # 查看状态
```

### 时间管理

```bash
source scripts/resume-time-remaining.sh
resume-time-remaining [project-name]    # 查看剩余分钟数

source scripts/resume-ask-time.sh
resume-ask-time [project-name]          # 设置剩余时间
```

### 紧急保存

```bash
source scripts/resume-urgent-save.sh
resume-urgent-save [project-name]
```

剩余不足 5 分钟时触发，执行保存并推送。

### 新环境一键恢复

如果项目初始化时已生成 `bootstrap.sh`：

```bash
export OPENCLAW_RESUME_PAT="ghp_xxx"
export OPENCLAW_RESUME_USER="your-user"
bash bootstrap.sh
```

自动下载技能到 `~/.openclaw/skills/openclaw-resume/` 并恢复项目。

## 目录结构

```
~/.openclaw-resume/<project-name>/
├── bootstrap.sh             # 新环境一键恢复脚本（自动生成）
├── progress.yaml            # 进度追踪
├── .pending_log             # 待处理的 log 标记
├── environment/
│   ├── requirements.txt
│   ├── apt-packages.txt
│   ├── env-vars.txt
│   └── setup.sh
├── workspace/
│   └── ...
├── checkpoints/
│   └── *.yaml
└── .git/
```

## 使用流程

### 首次使用
```
1. export OPENCLAW_RESUME_PAT="ghp_xxx"
2. export OPENCLAW_RESUME_USER="user"
3. git clone ... && cd openclaw-resume
4. source scripts/core.sh
5. source scripts/resume-init.sh
6. resume-init my-project          # 输入剩余时间
7. 正常工作...
8. resume-checkpoint "xxx"         # 关键节点
9. resume-save "会话结束"           # 结束前
```

### 恢复使用
```
1. source scripts/core.sh
2. source scripts/resume-restore.sh
3. resume-restore my-project       # 输入剩余时间
4. 继续工作...
```

### 新环境 bootstrap
```
1. export OPENCLAW_RESUME_PAT="ghp_xxx"
2. export OPENCLAW_RESUME_USER="user"
3. bash bootstrap.sh               # 自动安装技能 + 恢复
```

## 安全

- PAT 仅通过环境变量传递，不写入磁盘
- 状态仓库默认 private
- .gitignore 自动排除 .env、密钥文件等敏感信息
