# 好好吃饭 🍚

> 为身材管理而生的饮食记录工具

一款本地优先的饮食记录应用：日历打卡、热量结算、月度/年度统计、内置食物库、组合菜肴、饮食计划、局域网多端同步。支持 **Android / Windows / Web(PWA)** 三端，一套 Flutter 代码。

## 功能一览

| 模块 | 说明 |
|---|---|
| 📅 日历 | 月历视图，点击某天展开详情：记录餐次、食物、份量（克/毫升/碗/个）、喝水 |
| ⚖️ 结算 | 摄入 vs 消耗（BMR×活动系数 + 运动 MET）→ 缺口/盈余；**实时计算**，任何数据变化立即重算；对比自定义理想缺口判定达标；23:30 提醒 |
| 📊 统计 | 月：摄入/消耗双折线、缺口/盈余折线（含理想缺口参考线）、食物次数榜、饮水达标、达标天数；年：汇总卡、月度对比、体重趋势、食物 TOP10 |
| 📖 菜谱 | 内置 **176 种常见中国食物**（《中国食物成分表》第6版数据，含健身常用项）+ 6 道示例菜肴；支持自定义食物、单位换算、组合菜肴（多食材自动汇总营养） |
| 📝 计划 | 按天/模板规划每餐，条目可复制；日历当天显示"今日计划"参考卡，一键导入当天记录 |
| ⚖️ 体重 | 当日详情页记录/修改/删除体重（无需每天记），月/年趋势图 |
| 💧 饮水 | 每日目标（默认 1500ml 可改），进度展示 |
| 🏋️ 运动 | 内置 24 种运动（MET 估算），支持手动输入消耗 |
| 🔔 提醒 | 三餐/喝水/结算提醒（Android 通知 + Windows 应用内） |
| 🔄 同步 | 局域网扫码双向合并同步（PC 开启服务 → 手机同步）；JSON 全量导出/导入备份；数据层已为云端同步预留 |
| ✨ 激励 | 内置自律风 slogan 轮换 + 自定义 slogan |

## 技术栈

- Flutter 3.47 / Dart 3.13
- SQLite（sqflite + sqflite_common_ffi，Web 端 IndexedDB）
- 数据模型带 UUID + updatedAt + 软删除，行级 last-write-wins 合并（为云同步预留）
- fl_chart 图表、qr_flutter 二维码、shelf 局域网服务

## 构建

### 环境
- Flutter SDK 3.47+（Windows 桌面构建需 VS 2022 Build Tools，Android 构建需 JDK 17 + Android SDK）

### 命令
```bash
flutter pub get
flutter test                    # 单元/DB/UI 测试
flutter build web --release     # Web/PWA → build/web
flutter build apk --release     # Android APK → build/app/outputs/flutter-apk/
flutter build windows --release # Windows → build/windows/x64/runner/Release/
```
Windows 安装包：安装 [Inno Setup 6](https://jrsoftware.org/isdl.php)，编译 `tools/installer.iss`（输出到 `dist/`）。

### Android 签名
`android/app/release.keystore` 为正式签名（别名 `haohaochifan`，口令 `haohaochifan2026`）。
> ⚠️ 正式对外发布前请重新生成密钥并妥善保管；若仓库公开，请改用 GitHub Secrets 管理口令。

### GitHub Pages 部署
仓库已含 `.github/workflows/build-deploy.yml`：推送到 `main` 自动完成三件事——
- 构建 Web 并部署到 Pages
- 产出 Android APK 构件
- 在 windows 运行器上构建 **Windows 安装包**（`haohaochifan-setup-1.0.0.exe`，含 sqlite3.dll，无需本机装 VS）

仓库 Settings → Pages → Source 选 **GitHub Actions**，部署地址：`https://<用户名>.github.io/<仓库名>/`（iPhone 用 Safari 打开并"添加到主屏幕"即可安装为 PWA）。

## 数据与免责声明

- 所有数据存本机（Android/Windows 应用数据目录；Web 端 IndexedDB），无账号、无云上传
- 营养数据为《中国食物成分表（第6版）》等公开来源的近似值；消耗基于 Mifflin-St Jeor / MET 公式估算，**不构成医疗建议**
- 局域网同步需手机与电脑在同一 WiFi；Windows 首次使用同步需在防火墙放行 18623 端口

## 版本

v1.0.0 — 作者：星燃
