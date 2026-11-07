; Inno Setup script for the Windows installers. The workflow passes the values on the command line:
;   ISCC /DAppVersion=1.3.4 /DSourceDir=<stage folder> /DOutputDir=<folder> /DOutputName=<file name> [/DLegacy=1]
; The stage folder holds AudioGridderServer.exe, AudioGridderPluginTray.exe, VST3\, CLAP\, LV2\, Licenses\,
; README.txt and CHANGELOG.md.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "stage"
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif
#ifndef OutputName
  #define OutputName "AudioGridder-setup"
#endif

[Setup]
AppId={{6E2B6A0C-3F4D-4B7E-9A55-1D7C0F3B8A42}
AppName=AudioGridder
AppVersion={#AppVersion}
AppVerName=AudioGridder {#AppVersion}
AppPublisher=AudioGridder (marcosfork)
AppPublisherURL=https://github.com/MistaMin/audiogridder
AppSupportURL=https://github.com/MistaMin/audiogridder/issues
AppUpdatesURL=https://github.com/MistaMin/audiogridder/releases
DefaultDirName={autopf}\AudioGridder
DefaultGroupName=AudioGridder
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
#ifdef Legacy
MinVersion=6.1sp1
#else
MinVersion=10.0.14393
#endif
LicenseFile={#SourceDir}\Licenses\FREEWARE.txt
InfoBeforeFile={#SourceDir}\README.txt
OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\AudioGridderServer.exe
UninstallDisplayName=AudioGridder {#AppVersion}

[Types]
Name: "full"; Description: "Server and plug-ins"
Name: "server"; Description: "Server only (the computer that runs the plug-ins)"
Name: "plugins"; Description: "Plug-ins only (the computer that runs your DAW)"
Name: "custom"; Description: "Custom"; Flags: iscustom

[Components]
Name: "server"; Description: "AudioGridder Server"; Types: full server custom
Name: "tray"; Description: "AudioGridder Plugin Tray (runs next to your DAW)"; Types: full plugins custom
Name: "vst3"; Description: "VST3 plug-ins"; Types: full plugins custom
Name: "clap"; Description: "CLAP plug-ins"; Types: full plugins custom
Name: "lv2"; Description: "LV2 plug-ins"; Types: full plugins custom

[Files]
Source: "{#SourceDir}\AudioGridderServer.exe"; DestDir: "{app}"; Components: server; Flags: ignoreversion
Source: "{#SourceDir}\AudioGridderPluginTray.exe"; DestDir: "{app}"; Components: tray; Flags: ignoreversion
Source: "{#SourceDir}\VST3\*"; DestDir: "{commoncf64}\VST3"; Components: vst3; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourceDir}\CLAP\*"; DestDir: "{commoncf64}\CLAP"; Components: clap; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourceDir}\LV2\*"; DestDir: "{commoncf64}\LV2"; Components: lv2; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourceDir}\Licenses\*"; DestDir: "{app}\Licenses"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourceDir}\README.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\CHANGELOG.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\AudioGridder Server"; Filename: "{app}\AudioGridderServer.exe"; Components: server
Name: "{group}\AudioGridder Plugin Tray"; Filename: "{app}\AudioGridderPluginTray.exe"; Components: tray
Name: "{group}\Licenses"; Filename: "{app}\Licenses"
Name: "{group}\Uninstall AudioGridder"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\AudioGridderServer.exe"; Description: "Start AudioGridder Server"; Flags: nowait postinstall skipifsilent unchecked; Components: server
Filename: "{app}\AudioGridderPluginTray.exe"; Description: "Start AudioGridder Plugin Tray"; Flags: nowait postinstall skipifsilent unchecked; Components: tray
