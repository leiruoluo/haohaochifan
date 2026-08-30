; 好好吃饭 v1.0.0 Windows 安装脚本（Inno Setup 6）
; 用法：先 flutter build windows --release，再用 Inno Setup 编译本文件
#define MyAppName "好好吃饭"
#define MyAppVersion "1.0.0"
#define MyAppExeName "haohaochifan.exe"

[Setup]
AppId={{8F2C1E3A-9D6E-4F2A-8B1C-3D5E7F9A1C2D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=星燃
AppPublisherURL=
DefaultDirName={autopf}\好好吃饭
DefaultGroupName=好好吃饭
OutputDir=..\dist
OutputBaseFilename=haohaochifan-setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\tools\app_icon.ico

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务："

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\好好吃饭"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\好好吃饭"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "立即运行 好好吃饭"; Flags: nowait postinstall skipifsilent
