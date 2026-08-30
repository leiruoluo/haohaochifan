# 好好吃饭 - Windows 桌面版一键构建
# 前置：已以管理员身份运行 tools\install_vs_buildtools.ps1 安装 VS 2022 Build Tools
$ErrorActionPreference = 'Stop'
Set-Location "$PSScriptRoot\.."

$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'

Write-Host "=== 1/2 构建 Windows 桌面版 ===" -ForegroundColor Cyan
flutter build windows --release
if ($LASTEXITCODE -ne 0) { Write-Host "构建失败" -ForegroundColor Red; exit 1 }

# sqlite3.dll 运行时依赖（本机无系统 sqlite3，随应用分发）
$srcDll = Join-Path $PWD 'sqlite3.dll'
$releaseDir = Join-Path $PWD 'build\windows\x64\runner\Release'
if (Test-Path $srcDll) { Copy-Item $srcDll $releaseDir -Force; Write-Host "已复制 sqlite3.dll" }

Write-Host "=== 2/2 制作安装包（Inno Setup） ===" -ForegroundColor Cyan
$iscc = Get-ChildItem 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe', 'C:\Program Files\Inno Setup 6\ISCC.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($iscc) {
    & $iscc.FullName "$PWD\tools\installer.iss"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "安装包已生成：dist\haohaochifan-setup-1.0.0.exe" -ForegroundColor Green
    }
} else {
    Write-Host "未找到 Inno Setup，跳过安装包制作（可手动编译 tools\installer.iss）" -ForegroundColor Yellow
    Write-Host "可执行文件位于 build\windows\x64\runner\Release\haohaochifan.exe" -ForegroundColor Yellow
}
Write-Host "完成！" -ForegroundColor Green
