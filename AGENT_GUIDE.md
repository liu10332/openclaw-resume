# openclaw-resume Agent 使用指南

> 本文档描述 AI Agent 如何使用 openclaw-resume 工具管理限时试用环境的状态。

## 核心流程

### 场景 1：首次使用（新项目）

```
1. source scripts/resume-init.sh
2. resume-init <project-name>
3. 正常工作...
4. 关键步骤后：resume-checkpoint <描述>
5. 随时保存：resume-save <消息>
6. 启动定时器：resume-timer start <project-name>
```

**Agent 注意事项：**
- `resume-init` 会自动创建 GitHub 仓库、捕获环境、设置过期时间
- 初始化后立即启动定时器（`resume-timer start`）
- 每完成一个有意义的步骤后调用 `resume-checkpoint`

### 场景 2：恢复上次会话

```
1. source scripts/resume-restore.sh
2. resume-restore <project-name>
3. 继续工作...
```

**Agent 注意事项：**
- `resume-restore` 会自动拉取、恢复文件、恢复环境、启动定时器
- 恢复后先用 `resume-status` 确认进度
- 如果有未确认的检查点，询问用户是否确认

### 场景 3：工作中的保存节奏

```
每 15 分钟：定时器自动保存（无需干预）
关键节点：resume-checkpoint <描述>
随时保存：resume-save <消息>
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

### 场景 4：时间不足时

```
当 resume-time-remaining 返回 ≤ 5 分钟：
1. 自动触发紧急保存（resume-urgent-save）
2. 定时器自动停止
3. Agent 应提示用户时间即将到期
```

**Agent 行为：**
- 定期检查 `resume-time-remaining`
- 剩余 10 分钟时提醒用户
- 剩余 5 分钟时确保所有重要工作已保存
- 不要在最后 5 分钟开始大型任务

### 场景 5：会话结束

```
1. resume-save "会话结束，保存最终状态"
2. resume-timer stop
```

## 命令速查

| 命令 | 何时用 | 参数 |
|------|--------|------|
| `resume-init` | 首次使用 | `<project-name>` |
| `resume-restore` | 恢复会话 | `[project-name]` |
| `resume-save` | 随时保存 | `<message> [project-name]` |
| `resume-checkpoint` | 关键节点 | `<description> [project-name]` |
| `resume-checkpoint-confirm` | 确认检查点 | `<id> [project-name]` |
| `resume-env` | 重新捕获环境 | `[project-name]` |
| `env-restore` | 独立恢复环境 | `[project-name]` |
| `resume-status` | 查看进度 | `[project-name]` |
| `resume-time-remaining` | 查看剩余分钟 | `[project-name]` |
| `resume-urgent-save` | 紧急保存 | `[project-name]` |
| `resume-timer start` | 启动定时器 | `[project-name]` |
| `resume-timer stop` | 停止定时器 | — |
| `resume-timer status` | 查看定时器状态 | — |

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
