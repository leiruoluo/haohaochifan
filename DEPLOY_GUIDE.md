# 好好吃饭 - GitHub Pages 部署说明（iPhone 网页版）

> ⚠️ 免费账号的 GitHub Pages **只支持公开仓库**。代码会公开，但**签名密钥已改为 GitHub Secrets 保护**（仓库内不含密钥），放心公开。

## 第一步：创建公开仓库（浏览器，1 分钟）

1. 打开 https://github.com/new
2. Repository name 填：`haohaochifan`
3. 选 **Public**（免费 Pages 必需）
4. 不要勾选任何初始化选项（README/.gitignore/license 都不勾，保持空仓库）
5. 点 Create repository

## 第二步：添加两个 Secrets（浏览器，1 分钟）

打开仓库 → **Settings → Secrets and variables → Actions → New repository secret**，添加两条：

| Name | Secret（Value） |
|---|---|
| `KEYSTORE_BASE64` | 本机生成（见下方命令的输出） |
| `KEYSTORE_PASS` | `haohaochifan2026` |

> 本机生成 KEYSTORE_BASE64（在 PowerShell 里执行，把输出整段复制）：
> ```powershell
> [Convert]::ToBase64String([IO.File]::ReadAllBytes('D:\DSH\Have a good diet\android\app\release.keystore'))
> ```

## 第三步：本机推送（3 条命令）

```bash
cd D:\DSH\Have a good diet
git remote add origin https://github.com/leiruoluo/haohaochifan.git
git push -u origin main
```

> 若提示登录：浏览器会弹出 GitHub 授权页，点确认即可（Windows 会记住凭据）。

## 第四步：确认上线

1. 打开仓库 **Actions** 页，看到绿色对勾（首次构建约 3-5 分钟）
2. 打开仓库 **Settings → Pages**，确认 Source 为 **GitHub Actions**、状态为绿色
3. 网页版地址：`https://leiruoluo.github.io/haohaochifan/`
4. iPhone：Safari 打开 → 分享 → **添加到主屏幕** → 像 App 一样用

## Actions 自动产出的构件（Actions 页 → 本次运行 → Artifacts）

| 构件名 | 内容 |
|---|---|
| `haohaochifan-android-apk` | 正式签名 APK（用 Secrets 里的密钥） |
| `haohaochifan-windows-installer` | Windows 安装包（含 sqlite3.dll） |

## 以后每次更新

改完代码后 `git add -A && git commit -m "..." && git push` 即可，三端自动更新。
