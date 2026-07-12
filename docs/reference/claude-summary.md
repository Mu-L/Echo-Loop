# CLAUDE 摘要

> 说明：仓库规则禁止直接改 `CLAUDE.md`，因此这里提供压缩入口。
> 真实规则仍以根目录 `CLAUDE.md` 与 `AGENTS.md` 为准。

## 核心约束

- 文件驱动：决策落到 `PLAN.md` / `TASKS.md`。
- 单任务推进：一次只做一个任务。
- 最小改动：只改当前任务直接相关文件。
- 测试优先：功能与修复都要补验证。
- 类型安全：避免 `dynamic`、`as` 强转、`!` 非空断言。
- 文档同步：任务完成后更新 `TASKS.md`，必要时更新 `PLAN.md`。

## 开发流程

开始前：

1. 读 `PLAN.md`
2. 读 `TASKS.md`
3. 明确本次单一任务
4. 等待用户确认后修改

完成后：

1. 检查测试覆盖
2. 清理死代码
3. 检查中文注释
4. 运行与改动直接相关的 analyze / test
5. 更新 `TASKS.md`
6. 必要时更新 `PLAN.md`
7. 输出摘要

## 当前最重要的踩坑主题

- iOS 语音识别 session 隔离
- `flutter_tts` stop / speak 时序
- Android `versionCode` 必须全局单调递增
- Android 离线 ASR native 崩溃排查
- 锁屏媒体会话与前台播放隔离
- TTS 合成与缓存链路
- 词典非 modal 面板与流式 AI 词典协议

详细踩坑记录见根目录 [CLAUDE.md](../../CLAUDE.md) 第 7 节。
