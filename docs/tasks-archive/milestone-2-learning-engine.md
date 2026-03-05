# Milestone 2 已完成任务归档

> 归档时间：2026-03-05
> 里程碑：Milestone 2 - 学习流程引擎
> 完成任务数：40+ 个

## 归档摘要

本里程碑完成的主要工作：
- 基础设施：SharedPreferences → Drift 迁移、go_router 路由重构
- UI 优化：主题系统、导航重构、合集优化
- 音频功能：导入时长提取、字幕上传、星标、标签、合集复用
- 学习流程：全文盲听、逐句精听、难句跟读、段级复述
- 复习流程：间隔复习调度（7 轮）、难句补练、断点续学
- Bug 修复：自由练习退出、字幕显示、统计显示等

---

## Bug Fix

- [x] 首学-跟读阶段，自由练习模式下，最后一句的最后一遍听完之后没有跟读时间，并且直接退出页面了。应该在跟读时间结束之后，回到音频起始位置，而不是直接退出。并且要弹窗提醒用户是否再学一遍

  **完成时间**: 2026-03-03

- [x] 首学-逐句精听阶段，自由练习模式下，最后一句的最后一遍听完之后没有停顿时间，并且直接退出页面了。应该在停顿时间结束之后，回到音频起始位置，而不是直接退出。并且要弹窗提醒用户是否再学一遍

  **完成时间**: 2026-03-03

- [x] 在段落复述界面，把字幕显示选项一致设置为可点击，现在是只有播放完这一段才能点击

  **完成时间**: 2026-03-03

## 音频标签功能

- [x] 数据库层 — 新建 `tags` 和 `audio_item_tags` 两张表 + schema v8→v9 迁移 + 反向查询索引
- [x] 标签 Model — `lib/models/tag.dart`（id, name, colorValue, createdDate, color getter, copyWith）
- [x] 标签 DAO — `lib/database/daos/tag_dao.dart`（CRUD + Junction 操作 + CASCADE）
- [x] Provider 注册 — `tagDaoProvider` 添加到 `lib/database/providers.dart`
- [x] 标签 Provider — `lib/providers/tag_provider.dart`（TagState + TagList notifier + audioToTagsMap 反向索引 + diff 模式更新）
- [x] 集成 — 音频删除时清理标签缓存（`removeAudioFromAllTags`）
- [x] 集成 — 启动时加载标签（`main_shell.dart` 中 `loadTags()`）
- [x] 预定义颜色板 — `lib/theme/tag_colors.dart`（10 个颜色）
- [x] UI — 管理标签 BottomSheet — `lib/widgets/edit_tag_membership_sheet.dart`（CheckboxListTile + 颜色圆点 + 创建标签对话框 + 颜色选择）
- [x] UI — 音频列表项集成 — `AudioListTile` 新增"管理标签"菜单项 + 彩色标签 chips + `AudioListView` 传入回调
- [x] 国际化 — 6 个新 key
- [x] 代码生成 — `build_runner build` + `flutter gen-l10n`
- [x] 测试 — Tag Model 测试(4) + Tag DAO 测试(10) + TagState 测试(4) + EditTagMembershipSheet Widget 测试(4) + smoke test 修复
- [x] UI — 标签删除功能 — 删除按钮 + 确认对话框 + 国际化(+2 key) + Widget 测试(+1)
- [x] UX — 标签/合集 Sheet 改为即时生效

  **完成时间**: 2026-02-23

## 音频星标功能

- [x] 数据库表 `audio_items` 添加 `isStarred` 列 + schema v7→v8 迁移
- [x] AudioItem 模型添加 `isStarred` 字段
- [x] AudioLibraryProvider 添加 `toggleStar` 方法
- [x] SP 迁移 Companion 补充 `isStarred`
- [x] 国际化添加 `starAudio` / `unstarAudio` 字符串
- [x] AudioListTile 添加星标 IconButton
- [x] 测试

  **完成时间**: 2026-02-23

## 合集音频列表与全局音频列表复用

- [x] 统一 AudioListTile / AudioListView / AudioSortButton
- [x] CollectionDetailScreen 改用统一组件

  **完成时间**: 2026-02-23

## 音频导入时提取并存储时长

- [x] 新建 `lib/utils/audio_duration.dart`
- [x] 修改 `AddAudioDialog._addAudio()`
- [x] 清理多余时长回写逻辑

  **完成时间**: 2026-02-22

## 音频字幕上传/替换功能

- [x] 为音频添加上传/替换字幕功能

  **完成时间**: 2026-02-22

## 上传字幕时记录句子数和单词数

- [x] 数据库 + 模型 + 统计工具 + 集成 + 测试

  **完成时间**: 2026-02-22

## 资源库（Library）Tab 改造

- [x] 10 个子任务全部完成

  **完成时间**: 2026-02-22

## 基础设施：迁移到 go_router

- [x] 10 个子任务全部完成

  **完成时间**: 2026-02-21

## 基础设施：SharedPreferences → Drift 迁移

- [x] 10 个子任务全部完成

  **完成时间**: 2026-02-21

## 导航重构

- [x] Tab 改为 合集 | 学习 | 收藏 | 我的

  **完成时间**: 2026-02-20

## 优化 UI

- [x] 主题系统 + 各页面优化 + Learna AI 风格改造

  **完成时间**: 2026-02-21

## 优化合集 Tab

- [x] 6 个子任务全部完成

  **完成时间**: 2026-02-21

## 实现单个音频学习流程引擎

- [x] 学习计划表 + 数据模型 + 灵活性改进
- [x] 全文盲听模式 + Bug 修复 + 重构
- [x] 逐句精听 + 标注模式 + 设置
- [x] 难句跟读模式 + 设置 + Bug 修复
- [x] 段级复述模式 + Bug 修复 + UI 优化
- [x] 复习阶段基础闭环 + 结构统一 + 锁定防穿透
- [x] 复习解锁时机 + 可注入时钟 + 逾期窗口策略
- [x] 复习入口流程改造 + 真实复习页面
- [x] 难句补练 UI 改造 + 自由练习模式 + 断点续学
- [x] 集成测试 20 个

  **完成时间**: 2026-03-03
