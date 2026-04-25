# openclaw-resume 项目进度日志

## 当前状态
- **阶段**：v0.2.0 发布
- **日期**：2026-04-26

---

## 2026-04-26: v0.2.0 — 代码重构与 CLI 化

### M007: 代码重构与 CLI 化 ✅

#### S01: 代码重构 ✅
- 将 `detect_active_project` 统一到 core.sh（消除 9 个脚本中的重复定义）
- 将 `sync_workspace_to_state` 统一到 core.sh（消除 2 个脚本中的重复定义）
- 修复 `yaml_get` 双层 key 匹配错误（改用 awk 按 section 定位）
- 修复 `yaml_set` 双层 key 替换错误（先 awk 找行号再 sed）
- 修复 `resume-restore.sh` 中 `yaml_get progress_file` 缺少 `$` 前缀
- 修复 `yaml_get` 行内注释解析（`#` 后的内容不再被当作值）
- 去掉 core.sh 自动打印版本号（改为 `show_version` 函数）
- 新增 `list_all_projects` / `count_projects` 函数
- 版本号升至 0.2.0

#### S02: CRUD 命令 ✅
- `resume-list`：列出所有项目及状态（最后保存时间、任务、检查点数、定时器状态）
  - 支持 `--all` / `-a` 显示详细信息
- `resume-delete`：删除项目（本地 + 可选 GitHub 仓库）
  - 二次确认，`--force` 跳过确认
  - 自动检测并可选删除 GitHub 仓库
  - 停止关联的定时器

#### S03: CLI 统一入口 ❌ 已回退
- ~~resume.sh：统一 dispatch 所有子命令~~
- 回退原因：本项目是 OpenClaw Skill，用户是 AI Agent，不需要 CLI 安装层

#### S04: 一键安装 ❌ 已回退
- ~~install.sh：一键安装脚本~~
- 回退原因：同上，Agent 直接 source 脚本即可

#### S03b: 文档更新 ✅
- README.md：以 source 方式为核心，保留 list/delete 命令说明
- ROADMAP.md：新增 M007 里程碑
- PROGRESS.md：新增 v0.2.0 进度
- SKILL.md：更新版本号和命令列表
- AGENT_GUIDE.md：更新命令速查表

### 测试
- 从 33 项增加到 **54 项**，全部通过 ✅

---

## 2026-04-23: v0.1.0 — 初始版本

### M001: 核心框架 ✅
- S01 项目骨架与配置 ✅
- S02 同步引擎 ✅
- S03 init/restore 命令 ✅
- S04 save/status 命令 ✅

### M002: 自动化与环境恢复 ✅
- S01 环境捕获 ✅（pip/apt/npm/env-vars/setup.sh）
- S02 环境恢复 ✅（setup.sh + 独立 env-restore.sh）
- S03 自动同步定时器 ✅（resume-timer.sh，15分钟间隔）
- S04 checkpoint 命令 ✅（resume-checkpoint.sh + confirm）

### M003: 健壮性与用户体验 ✅
- S01 错误处理与重试 ✅（retry/git_push_safe/git_pull_safe/validate_pat）
- S02 时间感知 ✅（resume-urgent-save.sh + timer 紧急保存集成）
- S03 Agent 使用流程文档 ✅（AGENT_GUIDE.md）
- S04 端到端测试 ✅（tests/test-e2e.sh，33 项测试全通过）
