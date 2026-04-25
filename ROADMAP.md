# openclaw-resume 项目路线图

> 创建日期：2026-04-22
> 最后更新：2026-04-26
> 版本：0.2.0

## 项目目标

为在线 OpenClaw 试用环境（1小时限时）提供跨会话续接能力，通过 GitHub 同步状态，实现工作进度、代码文件和环境依赖的自动保存与恢复。

## 技术栈

- **实现语言**：Bash Shell 脚本
- **版本控制**：Git + GitHub（HTTPS + PAT 认证）
- **状态存储**：YAML 格式的 progress.yaml
- **包管理**：pip freeze + apt dpkg
- **定时同步**：Shell 后台循环 + sleep

## 里程碑规划

### M001: 核心框架（基础同步能力） ✅
**目标**：实现基本的 init/restore/save/sync 流程
**验证**：能在两个试用环境之间完整传递一个简单项目的状态

#### 切片
- **S01: 项目骨架与配置** — 目录结构、SKILL.md、config 模板、progress.yaml 模板
- **S02: 同步引擎** — sync.sh（push/pull/conflict）、GitHub 认证
- **S03: init/restore 命令** — 初始化状态仓库、从 GitHub 恢复
- **S04: save/status 命令** — 手动保存、进度查看

### M002: 自动化与环境恢复 ✅
**目标**：自动同步 + 环境依赖捕获恢复
**验证**：自动保存不丢数据，环境恢复后能正常运行项目

#### 切片
- **S01: 环境捕获** — env-capture.sh（pip/npm/apt/系统包）
- **S02: 环境恢复** — env-restore.sh（setup.sh 生成与执行）
- **S03: 自动同步定时器** — timer.sh（后台15分钟定时器）
- **S04: checkpoint 命令** — 检查点创建、确认、冲突解决

### M003: 健壮性与用户体验 ✅
**目标**：错误处理、边界情况、Agent 使用指南
**验证**：覆盖 95% 的异常场景，Agent 能无障碍使用

#### 切片
- **S01: 错误处理与重试** — 网络失败、认证失败、冲突解决
- **S02: 时间感知** — 检测剩余时间、紧急保存
- **S03: Agent 使用流程文档** — 标准操作流程、常见场景
- **S04: 端到端测试** — 完整流程验证

### M007: 代码重构与 CLI 化 ✅
**目标**：消除重复代码、修复 bug、提供统一 CLI 入口、一键安装
**验证**：54 项测试通过，`resume` 命令全局可用

#### 切片
- **S01: 代码重构** — 消除 9 处 detect_active_project 重复、2 处 sync_workspace_to_state 重复；修复 yaml_get/yaml_set 双层 key 解析；修复 resume-restore.sh 变量引用 bug
- **S02: CRUD 命令** — resume-list（列出项目+状态）、resume-delete（删除项目+可选 GitHub 仓库）
- **S03: CLI 统一入口** — resume.sh 统一 dispatch 所有子命令
- **S04: 一键安装** — install.sh（GitHub 下载 + 本地安装 + PATH 配置）
- **S05: 文档更新** — README、SKILL.md、AGENT_GUIDE.md、PROGRESS.md 全面更新

## 进度

| 里程碑 | 状态 | 进度 | 版本 |
|--------|------|------|------|
| M001   | ✅ 完成 | 100% | 0.1.0 |
| M002   | ✅ 完成 | 100% | 0.1.0 |
| M003   | ✅ 完成 | 100% | 0.1.0 |
| M007   | ✅ 完成 | 100% | 0.2.0 |

## 未来方向（按需）

| 里程碑 | 内容 | 优先级 |
|--------|------|--------|
| M004   | 多项目并行管理 + 快速切换 | 低 |
| M005   | GitHub Actions 自动测试 + 发布 | 中 |
| M006   | Web 面板查看状态 | 低 |
