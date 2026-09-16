#define AppVersion GetFileVersion(PublishDir + "\MarkdownViewer.exe")
[Setup]
AppId={{5BD21D30-930D-42C2-AC90-784E20CBB98A}
AppName=엠디봄
AppVersion={#ReleaseVersion}
VersionInfoVersion={#AppVersion}
AppPublisher=thlee
AppPublisherURL=https://github.com/thlee/mdbom
DefaultDirName={localappdata}\Programs\MarkdownViewer
DisableDirPage=yes
UsePreviousAppDir=no
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
UninstallDisplayIcon={app}\MarkdownViewer.exe
OutputDir={#OutputDir}
OutputBaseFilename=MDBom-{#ReleaseVersion}-Setup-x64
SetupIconFile=..\src\MarkdownViewer\Assets\app.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
CloseApplicationsFilter=MarkdownViewer.exe
RestartApplications=no
ChangesAssociations=yes
DisableProgramGroupPage=yes

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb"

[Icons]
Name: "{userprograms}\엠디봄"; Filename: "{app}\MarkdownViewer.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\MarkdownViewer.exe"; Description: "엠디봄 실행"; Flags: nowait postinstall skipifsilent

[Code]
function HasWebView2: Boolean;
var Version: String;
begin
  Result := (RegQueryStringValue(HKLM32, 'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Version) and (Version <> '') and (Version <> '0.0.0.0'));
  if not Result then
    Result := (RegQueryStringValue(HKCU32, 'Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Version) and (Version <> '') and (Version <> '0.0.0.0'));
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if not HasWebView2 then
    Result := 'Microsoft Edge WebView2 Runtime을 먼저 설치해 주세요. / Install Microsoft Edge WebView2 Runtime first: https://developer.microsoft.com/microsoft-edge/webview2';
end;

procedure RunRegistration(Script, Arguments: String);
var Code: Integer;
begin
  if not Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\') + Script + '" ' + Arguments,
    '', SW_HIDE, ewWaitUntilTerminated, Code) then
    RaiseException('Unable to start file association setup.');
  if Code <> 0 then RaiseException('File association setup failed. Exit code: ' + IntToStr(Code));
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then RunRegistration('Install.ps1', '-RegisterOnly');
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then RunRegistration('Uninstall.ps1', '-RegistrationOnly');
end;
