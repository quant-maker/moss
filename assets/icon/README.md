# 应用图标资源

请将以下图标文件放入此目录：

## 必需文件

1. **app_icon.png** - 主应用图标
   - 尺寸: 1024x1024 像素
   - 格式: PNG (带透明通道)
   - 用途: iOS 图标, Android 传统图标, Web 图标

2. **app_icon_foreground.png** - Android 自适应图标前景
   - 尺寸: 432x432 像素 (内容区域 324x324，周围留白)
   - 格式: PNG (带透明通道)
   - 用途: Android 8.0+ 自适应图标

3. **splash_logo.png** - 启动屏 Logo
   - 尺寸: 768x768 像素
   - 格式: PNG (带透明通道)
   - 用途: 应用启动屏

## 生成图标

在放置图标文件后，运行以下命令生成各平台图标：

```bash
# 生成应用图标
flutter pub run flutter_launcher_icons

# 生成启动屏
flutter pub run flutter_native_splash:create
```

## 设计建议

- 主图标使用 Moss 标志性的机器人/管家形象
- 主色调: #1565C0 (深蓝色)
- 图标风格: Material Design 3
- 保持简洁，避免过多细节

## 临时图标

如果没有正式图标，可以使用以下工具生成临时图标：
- https://romannurik.github.io/AndroidAssetStudio/
- https://appicon.co/
- https://www.figma.com/ (设计工具)
