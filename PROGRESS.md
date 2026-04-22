# openclaw-resume 项目进度日志

## 当前状态
- **阶段**：M001-S03 (init/restore 流程测试中)
- **已修复**：`fatal: not a git repository` 路径上下文丢失问题
- **已实施修复**：
    1. 修正了 `core.sh` 中 `yq` 兼容性问题。
    2. 完善了 `scripts/` 下各脚本的路径处理逻辑。
    3. 设计了 "关键节点触发" 的 Log 记录机制（替代 timeline，提高效率）。
    4. 实现了 `resume-ask-time.sh` 来解决虚拟机自动销毁导致的时间感知缺失。
    5. **统一所有脚本 git 操作为 `git -C <state_dir>` 模式，彻底解决路径依赖。**
    6. **修复 `env-capture.sh` 参数不匹配问题（init 直接调用 `capture_environment`）。**
    7. **修复 `add_log_entry` 的 sed 追加逻辑 bug。**
- **待办**：
    - 重新运行 `resume-init` 进行验证。
    - 开始 M002（环境恢复）测试。
