# 语音输入助手

一个独立的原生 macOS 菜单栏小工具：用全局快捷键录音，本地 Whisper 转写，然后把文字输入到当前光标位置。

## 功能

- 常驻菜单栏，无 Dock 图标。
- 默认快捷键：`Option + Space`。
- 支持两种录音模式：
  - 按住说话：按下快捷键开始，松开后转写并输入。
  - 开关录音：按一次开始，再按一次结束。
- 使用本地 `whisper.cpp` 的 `whisper-cli` 转写。
- 优先通过辅助功能 API 直写到当前输入框。
- 直写失败后自动使用剪贴板粘贴兜底，并恢复原剪贴板。
- 录音时菜单栏图标显示动态波形。
- 默认将中文转写结果转换为简体中文。

## 开发运行

```bash
swift run VoiceTyper
```

首次运行需要：

- 麦克风权限。
- 辅助功能权限。

本地 Whisper 资源由脚本下载/构建，默认放在：

```text
Sources/VoiceTyper/Resources/bin/whisper-cli
Sources/VoiceTyper/Resources/Models/ggml-base.bin
```

可以运行下面的脚本下载并构建 whisper.cpp，同时下载 base 多语言模型：

```bash
Scripts/bootstrap_whisper.sh
```

## 打包

```bash
Scripts/package_app.sh
open .build/VoiceTyper.app
```

打包脚本会把 `Resources` 下的 `whisper-cli` 和模型一起放进 `.app`，并进行本机 ad-hoc 签名。
