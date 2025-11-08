; Inno Setup Script for DBC Parser
; Requires Inno Setup 6.0 or later
; Download from: https://jrsoftware.org/isinfo.php
;
; To compile this script:
;   1. Install Inno Setup
;   2. Run: "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
;   3. Or open this file in Inno Setup and click Build -> Compile

#define MyAppName "DBC Parser"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Your Organization"
#define MyAppURL "https://github.com/dnasso/DBCFileViewer"
#define MyAppExeName "appDBC_Parser.exe"
#define MyAppAssocName "DBC File"
#define MyAppAssocExt ".dbc"
#define MyAppAssocKey StringChange(MyAppAssocName, " ", "") + MyAppAssocExt

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{A7B3C5D4-E6F7-8901-2345-6789ABCDEF01}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; Uncomment the following line to run in non administrative install mode (install for current user only.)
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=installer_output
OutputBaseFilename=DBC_Parser_Setup_{#MyAppVersion}
SetupIconFile=deploy-assets\dbctrain.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Require Windows 10 or later
MinVersion=10.0
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
; License file (uncomment if you have one)
;LicenseFile=LICENSE
; Show readme after installation
;InfoBeforeFile=README.md

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode
Name: "associatefiles"; Description: "Associate .dbc files with {#MyAppName}"; GroupDescription: "File Association:"
Name: "installsamplestodocs"; Description: "Install sample files to Documents folder"; GroupDescription: "Sample Files"; Flags: unchecked

[Files]
; Main application files from deployment directory
Source: "deploy\windows\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "deploy\windows\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Application icon
Source: "deploy-assets\dbctrain.ico"; DestDir: "{app}"; Flags: ignoreversion
; Sample DBC files and configs - install to app directory by default
Source: "SimpBMS-2.dbc"; DestDir: "{app}\samples"; Flags: ignoreversion; Tasks: not installsamplestodocs
Source: "sample_transmission_config.json"; DestDir: "{app}\samples"; Flags: ignoreversion; Tasks: not installsamplestodocs
Source: "simpbms_transmission_config.json"; DestDir: "{app}\samples"; Flags: ignoreversion; Tasks: not installsamplestodocs
; Sample DBC files and configs - install to Documents if selected
Source: "SimpBMS-2.dbc"; DestDir: "{userdocs}\DBC Parser Samples"; Flags: ignoreversion; Tasks: installsamplestodocs
Source: "sample_transmission_config.json"; DestDir: "{userdocs}\DBC Parser Samples"; Flags: ignoreversion; Tasks: installsamplestodocs
Source: "simpbms_transmission_config.json"; DestDir: "{userdocs}\DBC Parser Samples"; Flags: ignoreversion; Tasks: installsamplestodocs
; Documentation
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion isreadme
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Registry]
; File association for .dbc files (only if task is selected)
; When installed as admin (HKLM), available for all users
; When installed as user (HKCU), available only for current user
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocExt}\OpenWithProgids"; ValueType: string; ValueName: "{#MyAppAssocKey}"; ValueData: ""; Flags: uninsdeletevalue; Tasks: associatefiles
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocKey}"; ValueType: string; ValueName: ""; ValueData: "{#MyAppAssocName}"; Flags: uninsdeletekey; Tasks: associatefiles
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocKey}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: associatefiles
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocKey}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: associatefiles
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".dbc"; ValueData: ""; Tasks: associatefiles

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\dbctrain.ico"
Name: "{group}\{cm:ProgramOnTheWeb,{#MyAppName}}"; Filename: "{#MyAppURL}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\dbctrain.ico"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\dbctrain.ico"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Import Windows API function
function SetFileAttributes(lpFileName: string; dwFileAttributes: DWORD): BOOL;
  external 'SetFileAttributesW@kernel32.dll stdcall';

procedure SetReadOnly(FileName: string);
begin
  // FILE_ATTRIBUTE_READONLY = 0x00000001
  SetFileAttributes(FileName, $00000001);
end;

procedure RemoveReadOnly(FileName: string);
begin
  // Remove FILE_ATTRIBUTE_READONLY = 0x00000001
  SetFileAttributes(FileName, $00000000);
end;

// Function to check if Visual C++ Runtime is installed
function VCRedistNeedsInstall: Boolean;
var
  Version: String;
begin
  // Check for Visual C++ 2015-2022 Redistributable (x64)
  Result := not RegQueryStringValue(HKLM64, 
    'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 
    'Version', Version);
end;

// Custom page for VC++ Runtime installation
procedure InitializeWizard;
var
  VCRedistURL: string;
  ErrorCode: Integer;
begin
  VCRedistURL := 'https://aka.ms/vs/17/release/vc_redist.x64.exe';
  
  if VCRedistNeedsInstall then
  begin
    if MsgBox('This application requires the Microsoft Visual C++ Redistributable.' + #13#10 + 
              'Would you like to download and install it now?', 
              mbConfirmation, MB_YESNO) = IDYES then
    begin
      ShellExec('open', VCRedistURL, '', '', SW_SHOW, ewNoWait, ErrorCode);
      MsgBox('Please install the Visual C++ Redistributable and then continue with this installation.', 
             mbInformation, MB_OK);
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Remove readonly flag from sample files in Documents directory
    RemoveReadOnly(ExpandConstant('{userdocs}\DBC Parser Samples\SimpBMS-2.dbc'));
    RemoveReadOnly(ExpandConstant('{userdocs}\DBC Parser Samples\sample_transmission_config.json'));
    RemoveReadOnly(ExpandConstant('{userdocs}\DBC Parser Samples\simpbms_transmission_config.json'));
  end;
end;

[UninstallDelete]
Type: filesandordirs; Name: "{app}\samples"
Type: filesandordirs; Name: "{app}\docs"
