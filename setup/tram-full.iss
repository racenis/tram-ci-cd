; -- Example2.iss --
; Same as Example1.iss, but creates its icon in the Programs folder of the
; Start Menu instead of in a subfolder, and also creates a desktop icon.

; SEE THE DOCUMENTATION FOR DETAILS ON CREATING .ISS SCRIPT FILES!

[Setup]
AppName=Tramway SDK
AppVersion=0.1.1
AppPublisher=Tramway Drifting and Dungeon Exploration Simulator Expert Group
AppPublisherURL=https://racenis.github.io/tram-sdk/
AppSupportURL=https://racenis.github.io/tram-sdk/
AppUpdatesURL=https://racenis.github.io/tram-sdk/
AppCopyright=Copyright (C) 2021-2025 racenis
DefaultDirName={userappdata}\TramwaySDK
; Since no icons will be created in "{group}", we don't need the wizard
; to ask for a Start Menu folder name:
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\TramwaySDK.exe
;OutputDir=userdocs:Inno Setup Examples Output
;WizardImageFile=wizardimage.bmp
LicenseFile=license.txt

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