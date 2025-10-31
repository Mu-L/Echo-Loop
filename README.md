# Fluency - 专业英语听力练习应用

一款专业的英语听力练习应用，采用 Flutter 构建，支持跨平台运行。通过交互式音频播放和字幕支持，帮助语言学习者提升听力理解能力。

## ✨ 核心功能

### 📚 音频库管理
- 从本地导入音频文件（支持所有音频格式）
- 可选导入字幕文件（SRT/VTT 格式）
- 列表展示所有音频，标记是否包含字幕
- 显示添加日期，支持删除确认
- 持久化存储

### 🎵 三种播放模式
- **全文播放模式**：连续播放整个音频
- **单句播放模式**：逐句播放并自动暂停，精听利器
- **收藏播放模式**：只播放收藏的句子，针对性复习

### 🔄 灵活的循环播放
- 可配置循环次数（1-10 次或无限 ∞）
- 可配置暂停间隔（0-10 秒）
- 支持单句循环、全文循环、收藏句子循环

### ⭐ 智能收藏系统
- 点击星标即可收藏/取消收藏句子
- 收藏状态自动保存
- 收藏列表展示和快速跳转

### 🎮 完整的播放控制
- 播放/暂停/停止
- 上一句/下一句导航
- 进度条拖动定位
- 速度调节（0.5x - 2.0x）
- 点击句子直接跳转播放

### 📝 字幕功能
- 实时高亮当前播放句子
- 自动滚动到当前句子
- 显示时间轴
- 友好的空状态提示

## 🎨 高级功能

### 响应式设计
- **移动端**：底部导航栏，垂直布局
- **桌面端**：侧边导航栏，宽屏并排显示
- 自适应断点：600px 和 800px
- Material Design 3 设计语言

### 主题系统
- **浅色模式**：明亮清新
- **深色模式**：护眼舒适
- **跟随系统**：自动切换（默认）
- 主色调：蓝色 (#2196F3)
- 设置持久化保存

### 国际化支持
- **英文**（默认）
- **简体中文**
- 所有界面完全本地化
- 语言选择自动保存
- 易于扩展新语言

### 设置管理
- 独立的 Account（账户）栏目
- 主题模式选择
- 语言选择
- 关于信息和版本号

## 🛠️ 技术栈

### 音频处理
- **just_audio** - 专业音频播放引擎
- **audio_session** - 音频会话管理
- **audio_video_progress_bar** - 交互式进度条

### UI 框架
- **Flutter** - 跨平台 UI 框架
- **Material Design 3** - 设计语言
- **Provider** - 状态管理

### 国际化
- **flutter_localizations** - Flutter 官方 i18n
- **intl** - 格式化支持
- **gen-l10n** - 代码生成

### 字幕与文件
- **subtitle** - SRT/VTT 字幕解析
- **file_picker** - 跨平台文件选择

### 数据持久化
- **shared_preferences** - 本地存储
- **path_provider** - 路径管理

## 📁 项目结构

```
lib/
├── l10n/                         # 国际化
│   ├── app_en.arb               # 英文文案
│   ├── app_zh.arb               # 中文文案
│   └── app_localizations.dart   # 自动生成
├── models/                      # 数据模型
│   ├── audio_item.dart         # 音频项元数据
│   ├── sentence.dart           # 字幕句子数据
│   └── playback_settings.dart  # 播放配置
├── providers/                   # 状态管理
│   ├── audio_library_provider.dart  # 音频库管理
│   ├── player_provider.dart         # 播放控制
│   └── settings_provider.dart       # 设置管理
├── services/                    # 业务逻辑
│   ├── subtitle_parser.dart    # 字幕文件解析
│   └── storage_service.dart    # 数据持久化
├── screens/                     # 界面
│   ├── library_screen.dart     # 音频库界面
│   ├── player_screen.dart      # 播放器界面
│   └── settings_screen.dart    # 设置界面
├── widgets/                     # 可复用组件
│   ├── playback_controls.dart   # 播放控制
│   ├── sentence_list_view.dart  # 字幕列表
│   └── settings_panel.dart      # 设置面板
└── main.dart                    # 应用入口
```

## 🚀 快速开始

### 环境要求
- Flutter SDK 3.9.2 或更高版本
- iOS 模拟器 / Android 模拟器 / 真机
- 桌面端：macOS / Windows / Linux 开发环境

### 安装步骤

1. 克隆仓库
2. 安装依赖：
```bash
flutter pub get
```

3. 运行应用：
```bash
# 移动端
flutter run

# 指定平台
flutter run -d macos    # macOS
flutter run -d ios      # iOS
flutter run -d android  # Android
```

## 📖 使用指南

### 添加音频文件

1. 在音频库界面点击 **+** 按钮
2. 选择音频文件（MP3、WAV 等格式）
3. 可选：选择字幕文件（SRT 或 VTT 格式）
4. 音频将被添加到库中

### 播放控制

- **播放/暂停**：控制音频播放
- **上一句/下一句**：在句子间导航
- **停止**：停止播放并重置
- **进度条**：点击进度条跳转到指定位置
- **收藏**：点击 ⭐ 收藏句子

### 播放设置

点击 ⚙️ 图标进行配置：
- **播放速度**：0.5x 到 2.0x 调节
- **循环播放**：启用/禁用，设置循环次数
- **暂停间隔**：设置循环之间的停顿时间（0-10 秒）

### 播放模式切换

在播放器界面切换模式：
- **全文播放**：连续播放完整音频
- **单句播放**：逐句播放，自动重复
- **仅播放收藏**：复习收藏的句子

### 主题和语言

进入 Account（账户）栏目：
1. **主题模式**：选择浅色/深色/跟随系统
2. **语言**：选择 English 或简体中文

## 📝 字幕格式

应用支持标准字幕格式：

**SRT 示例：**
```srt
1
00:00:00,000 --> 00:00:03,000
Welcome to English listening practice.

2
00:00:03,500 --> 00:00:07,000
This is the second sentence.
```

**VTT 示例：**
```vtt
WEBVTT

00:00:00.000 --> 00:00:03.000
Welcome to English listening practice.

00:00:03.500 --> 00:00:07.000
This is the second sentence.
```

## 💡 使用场景

### 场景 1：精听单句
1. 导入音频和字幕
2. 切换到"单句播放"模式
3. 启用循环（如 3 次）
4. 设置暂停间隔（如 2 秒）
5. 反复练习每一句

### 场景 2：复习收藏
1. 播放过程中收藏难句
2. 切换到"仅播放收藏"模式
3. 专注练习收藏的句子

### 场景 3：整体泛听
1. 使用"全文播放"模式
2. 调整播放速度（如 0.75x）
3. 启用循环，反复听整篇

## 🎓 设计原则

- **模块化架构**：清晰的分层，职责分离
- **Provider 模式**：响应式状态管理
- **错误处理**：完整的异常处理和降级
- **响应式设计**：自适应移动端和桌面端
- **官方方案**：优先使用 Flutter 官方库
- **类型安全**：完整的 Dart null safety

## 🌐 平台支持

- ✅ iOS
- ✅ Android
- ✅ macOS
- ✅ Windows
- ✅ Linux

## 🔮 未来增强

可能的功能扩展：
- 云端同步音频库和收藏
- AB 循环（任意段落重复）
- 导出收藏列表
- 音频录制和对比
- 词典集成
- 更多语言支持

## 📄 许可证

本项目仅供教育和个人使用。

## 常用命令

```bash
# 生成图标
flutter pub run flutter_launcher_icons
# 安装 ios 版本
flutter devices
flutter run --release -d <device_id>
# 构建 macos 版本
flutter build macos --release
```