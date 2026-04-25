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

在线 OpenClaw 试用每次限时1小时，环境销毁后所有数据丢失。需要一套工具让下次试用能接续上次任务。

## 解决方案

通过 GitHub 仓库同步状态，实现：
- **进度追踪** — 关键节点触发记录（1小时约6-12条）
- **自动同步** — 每15分钟自动 push + 随时手动保存
- **环境恢复** — pip/npm/apt 依赖自动捕获和恢复
- **检查点续接** — 只取已确认的检查点，避免中间状态污染

## 前置条件

1. GitHub 个人访问令牌 (PAT)，设置为环境变量：
   ```bash
   export OPENCLAW_RESUME_PAT="ghp_xxxxxxxxxxxx"
   export OPENCLAW_RESUME_USER="your-github-username"
   ```
2. Git 已安装并可访问 GitHub

## 快速开始

```bash
# 克隆本项目
git clone https://你的token@github.com/liu10332/openclaw-resume.git
cd openclaw-resume

# 加载核心
source scripts/core.sh
```

## 命令

### 初始化新项目

```bash
source scripts/resume-init.sh
resume-init <project-name>
```

功能：
- 创建 GitHub 仓库 `{project-name}-state`
- 克隆到本地 `~/.openclaw-resume/{project-name}/`
- 生成 progress.yaml 初始版本
- 捕获当前环境依赖
- 询问用户剩余时间，设置过期时间
- 推送初始状态

### 恢复上次会话

```bash
source scripts/resume-restore.sh
resume-restore [project-name]
```

功能：
- 从 GitHub 拉取最新状态
- 读取 progress.yaml 显示上次进度
- 恢复工作文件到 workspace/
- 执行环境恢复（setup.sh）
- 启动自动同步定时器
- 询问用户剩余时间，设置过期时间

### 保存当前状态

```bash
source scripts/resume-save.sh
resume-save [message]
```

功能：
- 更新 progress.yaml（log 条目）
- 同步工作文件
- git add + commit + push
- 更新 last_saved 时间

### 创建检查点

```bash
source scripts/resume-checkpoint.sh
resume-checkpoint <description>
```

功能：
- 创建 pending 检查点
- 保存当前文件快照
- 推送到 GitHub
- 等待用户确认 → confirmed

### 列出所有项目

```bash
source scripts/resume-list.sh
resume-list [-a]
```

功能：
- 列出所有项目及状态摘要
- 显示最后保存时间、当前任务、检查点数、定时器状态
- `-a` 显示详细信息

### 删除项目

```bash
source scripts/resume-delete.sh
resume-delete <project-name> [--force]
```

功能：
- 显示项目摘要（任务、检查点、文件数）
- 二次确认，`--force` 跳过
- 可选删除 GitHub 仓库
- 停止关联的定时器
- 删除本地数据

### 查看状态

```bash
source scripts/resume-status.sh
resume-status [project-name]
```

### 捕获环境

```bash
source scripts/env-capture.sh
resume-env [project-name]
```

功能：
- pip freeze → requirements.txt
- npm ls -g → npm-global.json
- dpkg --get-selections → apt-packages.txt
- 捕获关键环境变量
- 生成 setup.sh

### 恢复环境

```bash
source scripts/env-restore.sh
env-restore [project-name]
```

功能：
- 执行 setup.sh（apt + pip + npm 差异安装）
- 恢复 package.json 到工作区
- 独立运行，不依赖 resume-restore

### 定时器控制

```bash
source scripts/resume-timer.sh
resume-timer start [project-name]   # 启动自动同步（每15分钟）
resume-timer stop                   # 停止自动同步
resume-timer status                 # 查看定时器状态
```

### 时间管理

```bash
source scripts/resume-time-remaining.sh
resume-time-remaining [project-name]    # 查看剩余分钟数

source scripts/resume-ask-time.sh
resume-ask-time [project-name]          # 交互式设置剩余时间
```

### 其他

```bash
source scripts/resume-urgent-save.sh
resume-urgent-save [project-name]   # 紧急保存（剩余<5分钟时）
```

## 目录结构

```
~/.openclaw-resume/<project-name>/    # 本地状态目录
├── progress.yaml                      # 进度追踪
├── .pending_log                       # 待处理的 log 标记
├── environment/                       # 环境依赖
│   ├── requirements.txt
│   ├── apt-packages.txt
│   ├── env-vars.txt
│   └── setup.sh
├── workspace/                         # 工作文件快照
│   └── ...
├── checkpoints/                       # 检查点
│   └── *.yaml
└── .git/                              # Git 仓库
```

## 使用流程

### 首次使用（新项目）
```
1. 设置 PAT: export OPENCLAW_RESUME_PAT="ghp_xxx"
2. 克隆: git clone ... && cd openclaw-resume
3. source scripts/core.sh && source scripts/resume-init.sh
4. 初始化: resume-init rag-tool-v3
5. 输入剩余时间: 55  ← Agent 会询问
6. 正常工作...
7. 定时器自动每15分钟同步
8. 关键步骤后: resume-checkpoint "完成OCR集成"
9. 结束前: resume-save "会话结束"
```

### 后续使用（恢复）
```
1. source scripts/core.sh && source scripts/resume-restore.sh
2. 恢复: resume-restore rag-tool-v3
3. 输入剩余时间: 50  ← Agent 会询问
4. 查看状态: resume-status
5. 继续上次的工作...
```

### 时间不足时的处理
```
Agent 自检：
  剩余 < 5 分钟 → 自动保存 + 提醒用户
  剩余 < 2 分钟 → 强烈提醒用户

用户可手动续期：
  resume-ask-time  ← 重新设置时间
```

## 安全注意事项

- PAT 仅存储在环境变量中，不写入磁盘
- 状态仓库默认 private
- .gitignore 自动排除 .env、密钥文件等敏感信息
