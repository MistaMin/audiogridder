AudioGridder @VERSION@ for Windows x64 @EDITION@
=================================================

This build was made by GitHub Actions. It has not been tested by the maintainer and the files are
not code signed, so Windows SmartScreen may warn about them ("More info", then "Run anyway").

INSTALLER
  Run the setup program. It installs, for all users:
    Programs   AudioGridderServer.exe, AudioGridderPluginTray.exe   C:\Program Files\AudioGridder
    VST3       the three .vst3 files                                C:\Program Files\Common Files\VST3
    CLAP       the three .clap files                                C:\Program Files\Common Files\CLAP
    LV2        the three .lv2 folders                               C:\Program Files\Common Files\LV2
  Choose "Server only" for the computer that runs your plug-ins, and "Plug-ins only" for the computer
  that runs your DAW. One computer can have both. Restart your DAW and rescan plug-ins afterwards.

USING IT
  1. On the computer that hosts the plug-ins, start AudioGridder Server and keep it running. Allow it
     through the Windows firewall when asked.
  2. On the computer with your DAW, start AudioGridder Plugin Tray and rescan plug-ins in your DAW.
  3. Insert AudioGridder, AudioGridder (inst) or AudioGridder (midi) on a track and choose the server.

NOT INCLUDED
  AAX (macOS only for now).

AudioGridder is freeware and is provided without warranty. See Licenses\FREEWARE.txt.
