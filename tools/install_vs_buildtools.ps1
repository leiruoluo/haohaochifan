# ============================================================
# 好好吃饭 - Windows 桌面版构建环境一键安装
# 请以【管理员身份】运行：右键本文件 -> 使用 PowerShell 运行
# 作用：安装 Visual Studio 2022 Build Tools（含 C++ 桌面工作负载）
# 需要约 4-6GB 下载空间，安装约 10-30 分钟
# ============================================================
$ErrorActionPreference = 'Stop'

Write-Host "=== 好好吃饭 Windows 构建环境安装 ===" -ForegroundColor Cyan
Write-Host "即将安装 Visual Studio 2022 Build Tools (C++ 桌面开发工作负载)"
Write-Host "请勿关闭本窗口，安装过程较久..."

$bootstrapper = "$env:TEMP\vs_BuildTools.exe"
Write-Host "下载安装引导器..." -ForegroundColor Yellow
curl.exe -L -sS -o $bootstrapper "https://aka.ms/vs/17/release/vs_BuildTools.exe"
if (-not (Test-Path $bootstrapper)) {
    Write-Host "下载失败，请手动下载 https://aka.ms/vs/17/release/vs_BuildTools.exe 后重试" -ForegroundColor Red
    exit 1
}

Write-Host "开始静默安装（C++ 桌面工作负载）..." -ForegroundColor Yellow
$args = @(
    "--add", "Microsoft.VisualStudio.Workload.VCTools",
    "--add", "Microsoft.VisualStudio.Component.Windows10SDK.19041",
    "--includeRecommended",
    "--quiet", "--norestart", "--wait"
)
$p = Start-Process -FilePath $bootstrapper -ArgumentList $args -Wait -PassThru
if ($p.ExitCode -in @(0, 3010)) {
    Write-Host "安装完成！现在可以回到 DSH 会话构建 Windows 桌面版。" -ForegroundColor Green
} else {
    Write-Host "安装退出码: $($p.ExitCode)（0 或 3010 表示成功，其他请重试）" -ForegroundColor Yellow
}
