# iOS App Store 上架清单（Echo Loop）

本文档只覆盖当前仓库已经能确认的 iOS 上架项，以及仍需你在 Apple 后台或真机上人工完成的项目。

发布命令与完整操作流程见：

- [docs/ios-release-publish.md](/Volumes/SamsungT7/workspace/fluency/fluency/docs/ios-release-publish.md)

## 当前仓库内已确认

- App 显示名已做多语言：
  - 英文系统：`Echo Loop`
  - 简体中文系统：`Echo Loop`
- Bundle ID：`top.echo-loop`
- App 类别：`Education`
- App Icon 资源集已存在：`ios/Runner/Assets.xcassets/AppIcon.appiconset`
- Universal Links 已配置：
  - `Associated Domains`
  - `apple-app-site-association`
  - 详情见 [docs/ios-universal-links.md](/Volumes/SamsungT7/workspace/fluency/fluency/docs/ios-universal-links.md)
- 当前已声明的 iOS 权限文案：
  - `NSPhotoLibraryUsageDescription`
  - `NSAppleMusicUsageDescription`
  - `NSLocalNetworkUsageDescription`

## 上架前你需要在 Apple 后台准备

- App Store Connect 中创建 App，Bundle ID 选择 `top.echo-loop`
- App 名称、副标题、关键词、描述、推广文案
- 隐私政策 URL
- 支持 URL
- App 截图：
  - 6.7" iPhone
  - 6.5" 或 6.3" iPhone
  - iPad（如果你计划上架 iPad）
- App Icon 最终视觉人工确认
- 年龄分级问卷
- App Privacy 营养标签问卷
- 审核备注与测试账号（如果审核流程需要）

## 真机发布前建议人工检查

1. `Bundle Identifier` 显示为 `top.echo-loop`
2. App 主屏名称显示为 `Echo Loop`
3. 首次安装后，导入音频、选择字幕、播放音频流程正常
4. `echo-loop.top` 的 Universal Links 能拉起 App
5. 离线启动、后台音频、通知跳转不出现崩溃

## 暂时不要提前加的权限

当前仓库还没完成“录音 + 识别功能”，因此这两项建议等功能真实接入后再加：

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

原因是现在提前声明，审核时如果功能入口和实际行为对不上，反而会增加解释成本。
