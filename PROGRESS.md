# openclaw-resume 项目进度日志

## 当前状态
- **阶段**：M001-S03 (init/restore 流程测试中)
- **主要问题**：`resume-init.sh` 在执行 Git 操作时路径上下文丢失，导致 `fatal: not a git repository`。
- **已实施修复**：
    1. 修正了 `core.sh` 中 `yq` 兼容性问题。
    2. 完善了 `scripts/` 下各脚本的路径处理逻辑。
    3. 设计了 "关键节点触发" 的 Log 记录机制（替代 timeline，提高效率）。
    4. 实现了 `resume-ask-time.sh` 来解决虚拟机自动销毁导致的时间感知缺失。
- **待办**：
    - 统一 Git 操作采用 `git -C <dir>` 模式，彻底解决路径依赖。
    - 重新运行 `resume-init` 进行验证。
    - 开始 M002（环境恢复）测试。
