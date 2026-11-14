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
Source: "Ensure-WebView2.ps1"; Flags: dontcopy
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb"

[Icons]
Name: "{userprograms}\엠디봄"; Filename: "{app}\MarkdownViewer.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\MarkdownViewer.exe"; Description: "엠디봄 실행"; Flags: nowait postinstall skipifsilent; Check: CanLaunchApplication

[Code]
var
  RuntimePage: TOutputProgressWizardPage;
  RuntimeRestartRequired: Boolean;

procedure InitializeWizard;
begin
  RuntimePage := CreateOutputProgressPage('Microsoft Edge WebView2',
    '필수 구성 요소 준비 / Preparing required component');
end;

function CanLaunchApplication: Boolean;
begin
  Result := not RuntimeRestartRequired;
end;

function HasWebView2: Boolean;
var Version: String;
begin
  Result := (RegQueryStringValue(HKLM32, 'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Version) and (Version <> '') and (Version <> '0.0.0.0'));
  if not Result then
    Result := (RegQueryStringValue(HKCU32, 'Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Version) and (Version <> '') and (Version <> '0.0.0.0'));
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var Code: Integer; Details: AnsiString;
begin
  Result := '';
  if HasWebView2 then exit;
  RuntimePage.SetText('WebView2를 Microsoft에서 다운로드하고 설치합니다. 잠시 기다려 주세요.',
    'Downloading and installing WebView2 from Microsoft. Internet access is required.');
  RuntimePage.Show;
  try
    try
      ExtractTemporaryFile('Ensure-WebView2.ps1');
      DeleteFile(ExpandConstant('{tmp}\webview2-error.txt'));
      if not Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
        '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + ExpandConstant('{tmp}\Ensure-WebView2.ps1') +
        '" -WorkingDirectory "' + ExpandConstant('{tmp}') + '"', '', SW_HIDE, ewWaitUntilTerminated, Code) then
        RaiseException('Unable to start WebView2 setup.');
      if LoadStringFromFile(ExpandConstant('{tmp}\webview2-error.txt'), Details) then Log(String(Details));
      if ((Code <> 0) and (Code <> 3010)) or (not HasWebView2) then
        RaiseException('WebView2 setup did not complete. Exit code: ' + IntToStr(Code));
      RuntimeRestartRequired := Code = 3010;
      NeedsRestart := RuntimeRestartRequired;
    except
      Log(GetExceptionMessage);
      Result := 'WebView2 자동 설치를 완료하지 못했습니다. 인터넷 연결이나 조직 보안 정책을 확인하고 다시 시도하세요. 재부팅 안내를 받았다면 Windows를 다시 시작하세요.' + #13#10 +
        'WebView2 setup failed. Check your connection or organization policy and retry. Restart Windows if requested.' + #13#10 +
        '오프라인 PC에서는 Microsoft의 Evergreen Standalone Installer (x64)를 먼저 설치하세요. / Offline: install the Evergreen Standalone Installer (x64) first.' + #13#10 +
        'https://developer.microsoft.com/microsoft-edge/webview2';
    end;
  finally
    RuntimePage.Hide;
  end;
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
