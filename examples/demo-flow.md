# openclaw-resume 使用示例

## 场景：开发 rag-tool-v3 的 OCR 模块

### 第一天上午（首次使用）

```
# 1. 配置环境变量
export OPENCLAW_RESUME_PAT="ghp_xxxx"
export OPENCLAW_RESUME_USER="liu10332"

# 2. 初始化
> resume-init rag-tool-v3
[INFO] 初始化 openclaw-resume 项目: rag-tool-v3
[STEP] 创建 GitHub 仓库...
[STEP] 克隆状态仓库...
[STEP] 创建目录结构...
[STEP] 生成进度文件...
[STEP] 捕获环境依赖...
[STEP] 推送到 GitHub...
[INFO] ✅ 项目 rag-tool-v3 初始化完成

# 3. 开始工作
# Agent 更新进度：
#   position.project = "rag-tool-v3"
#   position.module = "parser"
#   position.task_name = "PDF OCR 集成"
#   position.task_status = "in_progress"
#   position.current_step = 1
#   position.total_steps = 7
#   position.step_description = "编写 OCR 单元测试"

# 4. 工作中... 定时器自动每15分钟同步
# 5. 关键节点手动保存
> resume-checkpoint "OCR 单元测试框架搭建完成"
[INFO] ✅ 检查点 #1 已创建: OCR 单元测试框架搭建完成

# 6. 继续工作...

# 7. 快到1小时了
> resume-save "会话结束，OCR 测试框架完成，下一步写具体测试用例"
[INFO] ✅ 保存成功

# 8. 停止定时器
> resume-timer stop
[INFO] ✅ 定时器已停止
[INFO] 执行最后一次同步...
[INFO] ✅ 保存成功
```

**→ 环境销毁，数据已安全在 GitHub**

---

### 第一天下午（恢复）

```
# 1. 新的试用环境，配置环境变量
export OPENCLAW_RESUME_PAT="ghp_xxxx"
export OPENCLAW_RESUME_USER="liu10332"

# 2. 加载 skill，恢复
> resume-restore rag-tool-v3
[STEP] 从 GitHub 拉取最新状态...
[STEP] 读取上次进度...

═══════════════════════════════════════════
  📋 上次进度
═══════════════════════════════════════════
  项目: rag-tool-v3
  任务: PDF OCR 集成
  步骤: 1
  备注: OCR 单元测试框架搭建完成
═══════════════════════════════════════════

[STEP] 恢复工作文件...
[INFO] 工作文件已恢复到 ~/workspace/
[STEP] 恢复环境依赖...
[INFO] 执行环境恢复脚本...
[INFO] Python 依赖无差异
[STEP] 启动自动同步定时器...
[INFO] ✅ 定时器已启动

[INFO] ✅ 恢复完成，继续上次的工作吧
```

# 3. 查看状态
> resume-status
╔═══════════════════════════════════════════════╗
║         openclaw-resume 状态面板              ║
╚═══════════════════════════════════════════════╝

  📦 项目: rag-tool-v3
  🆔 会话: 2026-04-22-pm-1

  ┌─ 时间 ─────────────────────────────────────┐
  │ 开始: 2026-04-22T14:00:00+08:00
  │ 过期: 2026-04-22T15:00:00+08:00
  │ 剩余: 58 分钟
  │ 最后保存: 2026-04-22T14:00:00+08:00
  │ 定时器: 运行中 ✓
  └────────────────────────────────────────────┘

  ┌─ 当前进度 ─────────────────────────────────┐
  │ 任务: PDF OCR 集成
  │ 进度: 1/7
  │ 备注: OCR 单元测试框架搭建完成
  └────────────────────────────────────────────┘

  ┌─ 检查点 ───────────────────────────────────┐
  │ 总计: 1 | 已确认: 1 | 待确认: 0
  └────────────────────────────────────────────┘

# 4. 继续从步骤2开始工作
# Agent 随手更新：
#   position.task = "PDF OCR 集成"
#   position.step = "2"
#   position.note = "正在写中文测试用例"

# 5. 步骤2完成后
> resume-checkpoint "中文PDF识别测试用例完成，准确率 88%"
[INFO] ✅ 检查点 #2 已创建

# 6. 继续工作...
# 定时器自动同步...

# 7. 结束
> resume-timer stop
```

---

### 场景：同一天多次使用后的冲突处理

```
上午 9:00   创建检查点 #1 (confirmed) - "OCR框架完成"
上午 9:55   创建检查点 #2 (pending)   - "测试用例写到一半"
            ↑ 还没确认就到时间了

下午 2:00   resume-restore

恢复策略：
  → 从 GitHub 拉取
  → 读取 checkpoints/
  → #2 是 pending，跳过
  → #1 是 confirmed，从这里恢复
  → 但 workspace/ 中保留了 #2 写了一半的文件
```

---

### 场景：环境差异处理

```
# 上午的环境
Python 3.11.8
paddleocr==2.7.0

# 下午的试用环境
Python 3.10.12
paddleocr 未安装

# 恢复时自动执行 setup.sh
[INFO] 检查系统包差异...
[INFO] 安装缺失的系统包: libgl1-mesa-glx
[INFO] 安装 Python 依赖...
[INFO] 安装 paddleocr==2.7.0
[INFO] ✅ 环境恢复完成
```
