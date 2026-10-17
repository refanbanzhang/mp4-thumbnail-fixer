# MP4 缩略图修复器

一个原生 macOS 小工具，用于把 MPEG-TS 等视频容器无损重封装为标准 MP4，
让 Finder / Quick Look 可以生成视频缩略图。

## 使用

1. 双击打开 `dist/MP4缩略图修复器.dmg`。
2. 将视频拖入窗口，或点击「选择视频」。
3. 程序会在原文件旁生成 `文件名-fixed.mp4`。
4. 原文件不会被覆盖，也不会重新编码。

支持批量处理。输出文件存在时会自动使用 `-fixed-1.mp4` 等新名称。

## 构建 DMG

本项目针对 Apple Silicon Mac，要求：

- macOS 13 或更高版本
- Xcode Command Line Tools
- Homebrew ffmpeg：`brew install ffmpeg`

执行：

```bash
./build-dmg.sh
```

产物位于：

```text
dist/MP4缩略图修复器.dmg
```

当前 DMG 使用本地 ad-hoc 签名。首次打开时如果 macOS 阻止启动，
请右键 App 选择「打开」。
