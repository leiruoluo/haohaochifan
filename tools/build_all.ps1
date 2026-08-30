# 好好吃饭 - 一键构建脚本（本机已装好 Flutter SDK 与 Android SDK 时使用）
# 中国大陆网络自动启用国内镜像源
$ErrorActionPreference = 'Stop'
Set-Location "$PSScriptRoot\.."

# 国内镜像（大陆网络必需）
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
# Gradle 镜像（首次构建前建议复制 tools\gradle-init.gradle 到 ~\.gradle\init.gradle）

$target = if ($args.Count -gt 0) { $args[0] } else { 'all' }

switch ($target) {
  'test' {
    Write-Host "=== 运行测试 ===" -ForegroundColor Cyan
    flutter test
  }
  'apk' {
    Write-Host "=== 构建 Android APK ===" -ForegroundColor Cyan
    flutter build apk --release
    Write-Host "产物: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
  }
  'web' {
    Write-Host "=== 构建 Web/PWA ===" -ForegroundColor Cyan
    flutter build web --release
    Write-Host "产物: build\web" -ForegroundColor Green
  }
  'windows' {
    Write-Host "=== 构建 Windows 桌面版（需 VS 2022 Build Tools）===" -ForegroundColor Cyan
    flutter build windows --release
    Write-Host "产物: build\windows\x64\runner\Release\" -ForegroundColor Green
  }
  default {
    Write-Host "=== 全量：测试 + APK + Web ===" -ForegroundColor Cyan
    flutter test
    flutter build apk --release
    flutter build web --release
  }
}
Write-Host "完成 ✅" -ForegroundColor Green
