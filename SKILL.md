---
name: openclaw-resume
description: "OpenClaw 限时试用环境跨会话续接工具 — 自动同步状态到 GitHub，恢复上次进度、代码和环境依赖。"
version: 0.1.0
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

## 命令

### 初始化新项目

```bash
source scripts/resume-init.sh
resume-init <project-name>
```

功能：
- 创建 GitHub 仓库 `{project-name}-state`（需手动或用 gh CLI）
- 克隆到本地 `.openclaw-resume/{project-name}/`
- 生成 progress.yaml 初始版本
- 捕获当前环境依赖
- **询问用户剩余时间**，设置过期时间
- 推送初始状态

### 恢复上次会话

```bash
source scripts/resume-restore.sh
resume-restore <project-name>
```

功能：
- 从 GitHub 拉取最新状态
- 读取 progress.yaml 显示上次进度
- 恢复工作文件到 workspace/
- 执行环境恢复（setup.sh）
- 启动自动同步定时器
- **询问用户剩余时间**，设置过期时间

### 设置环境剩余时间

```bash
source scripts/resume-ask-time.sh
resume-ask-time [project-name]
```

功能：
- 询问用户当前环境还剩多少分钟
- 计算并更新 progress.yaml 的 expires_at
- 返回剩余分钟数

**使用时机：**
- init 时自动调用
- restore 时自动调用
- 用户手动调用（如环境刷新后）

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

### 捕获环境

```bash
source scripts/resume-env.sh
resume-env
```

功能：
- pip freeze → requirements.txt
- 检测 package.json
- dpkg --get-selections → apt-packages.txt
- 生成 setup.sh

### 查看状态

```bash
source scripts/resume-status.sh
resume-status
```

### 查看剩余时间

```bash
source scripts/resume-time-remaining.sh
resume-time-remaining [project-name]
```

### 定时器控制

```bash
source scripts/resume-timer.sh
resume-timer start   # 启动自动同步（每15分钟）
resume-timer stop    # 停止自动同步
resume-timer status  # 查看定时器状态
```

## 目录结构

```
~/.openclaw-resume/{project-name}/    # 本地状态目录
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
2. 初始化: resume-init rag-tool-v3
3. 输入剩余时间: 55  ← Agent 会询问
4. 正常工作...
5. 定时器自动每15分钟同步
6. 关键步骤后: resume-checkpoint "完成OCR集成"
7. 结束前: resume-save "会话结束"
```

### 后续使用（恢复）
```
1. 恢复: resume-restore rag-tool-v3
2. 输入剩余时间: 50  ← Agent 会询问
3. 查看状态: resume-status
4. 继续上次的工作...
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

- PAT 仅存储在环境变量中，不同步到 GitHub
- 状态仓库建议设为 private
- .gitignore 自动排除 .env、密钥文件等敏感信息
