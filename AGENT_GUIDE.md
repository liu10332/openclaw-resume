# openclaw-resume Agent 使用指南

> 本文档描述 AI Agent 如何使用 openclaw-resume 工具管理限时试用环境的状态。
> 版本：0.2.0

## 前置条件

```bash
export OPENCLAW_RESUME_PAT="ghp_xxxxxxxxxxxx"
export OPENCLAW_RESUME_USER="your-github-username"
```

## 核心流程

### 场景 1：首次使用（新项目）

```bash
# 初始化
resume init <project-name>

# 正常工作...
# 关键步骤后
resume checkpoint "完成OCR集成"

# 随时保存
resume save "调试中"

# 启动定时器（init 时可能已自动启动）
resume timer start <project-name>
```

**Agent 注意事项：**
- `resume init` 会自动创建 GitHub 仓库、捕获环境、设置过期时间
- 初始化后确认定时器已启动（`resume timer status`）
- 每完成一个有意义的步骤后调用 `resume checkpoint`

### 场景 2：恢复上次会话

```bash
# 恢复
resume restore <project-name>

# 确认进度
resume status

# 继续工作...
```

**Agent 注意事项：**
- `resume restore` 会自动拉取、恢复文件、恢复环境、启动定时器
- 恢复后先用 `resume status` 确认进度
- 如果有未确认的检查点，询问用户是否确认

### 场景 3：查看项目

```bash
# 列出所有项目
resume list

# 详细信息
resume list -a

# 查看某个项目状态
resume status <project-name>

# 查看变化
resume diff <project-name>
```

### 场景 4：工作中保存

```
每 15 分钟：定时器自动保存（无需干预）
关键节点：resume checkpoint <描述>
随时保存：resume save <消息>
```

**Agent 判断何时 checkpoint：**
- 完成一个文件的编写/修改
- 测试通过
- 安装了新依赖
- 用户做了重要决策
- 从错误中恢复

**跳过 checkpoint：**
- 连续的无变化操作
- 简单的文件读取
- 思考/规划阶段

### 场景 5：时间不足

```bash
# 查看剩余时间
resume time <project-name>

# 当剩余 ≤ 5 分钟时：
# 1. 自动触发紧急保存
# 2. 定时器自动停止
# 3. Agent 应提示用户时间即将到期

# 用户可手动续期
resume ask-time <project-name>
```

### 场景 6：会话结束

```bash
resume save "会话结束，保存最终状态"
resume timer stop
```

### 场景 7：删除项目

```bash
# 交互式删除
resume delete <project-name>

# 强制删除（跳过确认）
resume delete <project-name> --force
```

## 命令速查

| 命令 | 何时用 | 参数 |
|------|--------|------|
| `resume init` | 首次使用 | `<project-name> [work-dir]` |
| `resume restore` | 恢复会话 | `[project-name]` |
| `resume save` | 随时保存 | `[message]` |
| `resume checkpoint` | 关键节点 | `<description>` |
| `resume status` | 查看进度 | `[project-name]` |
| `resume list` | 列出项目 | `[-a]` |
| `resume delete` | 删除项目 | `<name> [--force]` |
| `resume diff` | 查看变化 | `[project-name]` |
| `resume env` | 捕获环境 | `[project-name]` |
| `resume env-restore` | 恢复环境 | `[project-name]` |
| `resume time` | 剩余分钟 | `[project-name]` |
| `resume ask-time` | 设置时间 | `[project-name]` |
| `resume timer start` | 启动定时器 | `[project-name]` |
| `resume timer stop` | 停止定时器 | — |
| `resume timer status` | 定时器状态 | — |

## 错误处理

### 网络失败
- push 失败 → 自动重试 3 次（含 rebase）
- pull 失败 → 自动重试 3 次
- 持续失败 → 数据保存在本地，下次同步会重试

### PAT 过期
- `validate_pat` 会检测并提示
- Agent 应提醒用户更新 PAT

### 仓库不存在
- init 时自动创建
- restore 时如不存在则报错

### 冲突
- 自动尝试 rebase
- 如仍有冲突，使用本地版本并提示用户

## 最佳实践

1. **项目名用小写字母和连字符**：`my-project`，不要用空格或特殊字符
2. **checkpoint 描述要具体**：`完成用户登录模块` 优于 `做了些修改`
3. **不要在 checkpoint 之间做太多事**：一个 checkpoint 代表一个可恢复的点
4. **定期检查剩余时间**：避免环境突然销毁
5. **重要操作前先 save**：安装大依赖、重构代码前确保已保存
