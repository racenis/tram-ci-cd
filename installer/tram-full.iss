; Tramway SDK full installer.
; Invoked by installer/build.sh after staging setupfiles/ into the current directory.

[Setup]
AppName=Tramway SDK
AppVersion=0.1.1
AppPublisher=Tramway Drifting and Dungeon Exploration Simulator Expert Group
AppPublisherURL=https://racenis.github.io/tram-sdk/
AppSupportURL=https://racenis.github.io/tram-sdk/
AppUpdatesURL=https://racenis.github.io/tram-sdk/
AppCopyright=Copyright (C) 2021-2026 racenis
DefaultDirName={userappdata}\TramwaySDK
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\tram-binary\projectmanager.exe
LicenseFile=license.txt
OutputBaseFilename=tramway-sdk-setup
;WizardImageFile=wizardimage.bmp

[Components]
Name: "sdk_files"; Description: "Main SDK files"; Types: full compact custom; Flags: fixed
Name: "templates"; Description: "Templates"; Types: full compact custom; Flags: fixed
Name: "templates/template"; Description: "Teapot Explorer"; Types: full compact custom; Flags: fixed

[Files]
Source: "setupfiles\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{commonprograms}\Tramway SDK"; Filename: "{app}\tram-binary\projectmanager.exe"
Name: "{commondesktop}\Tramway SDK"; Filename: "{app}\tram-binary\projectmanager.exe"

[Run]
Filename: "{app}\tram-binary\projectmanager.exe"; Description: "Launch Tramway SDK"; Flags: postinstall nowait skipifsilent
