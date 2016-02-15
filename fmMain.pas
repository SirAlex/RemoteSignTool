unit fmMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, IdBaseComponent, IdComponent,
  IdCustomTCPServer, IdCustomHTTPServer, IdHTTPServer, Vcl.StdCtrls,
  Vcl.ExtCtrls, IdContext;

type
  TMainForm = class(TForm)
    pnTop: TPanel;
    edSigntoolPath: TLabeledEdit;
    memLog: TMemo;
    edHttpPort: TLabeledEdit;
    httpServ: TIdHTTPServer;
    btStart: TButton;
    edSigntoolCmdLine: TLabeledEdit;
    edCross: TLabeledEdit;
    procedure httpServAfterBind(Sender: TObject);
    procedure httpServCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    procedure btStartClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
    procedure StartHTTPServer;
    function TrySignFile:boolean;

    procedure LoadSettings;
    procedure SaveSettings;
    procedure FlushLog;
  public
    procedure Log(const AMessage:string);

    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

uses  IOUtils,
      System.NetEncoding,
      System.IniFiles,
      System.StrUtils;

{$R *.dfm}

function GetTempFilename(const APrefix:string=''; const AExt:string=''):string;
var
  guid: string;
begin
  guid := TGUID.NewGuid.ToString;
  result := APrefix + guid + ifthen(AExt='','.tmp',AExt);
end;

function CreateInheritable(out Sa: TSecurityAttributes): PSecurityAttributes;
begin
  Sa.nLength := SizeOf(Sa);
  Sa.lpSecurityDescriptor := nil;
  Sa.bInheritHandle := True;
  Result := @Sa;
end;

function CreateDOSProcessRedirected(CommandLine: string; var StdErr: string; Hidden:boolean=true): Cardinal;
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  SecAtrrs: TSecurityAttributes;
  hOutputFile: THandle;
  rz: boolean;
  tempname: string;
begin
  MainForm.Log('Exec: '+CommandLine);
  Result := 255;
  tempname := GetTempFileName('sign','.txt');
//  setlength(tempname, MAX_PATH);
//  GetTempFileName('.','signtool', 0, @tempname[1]);
//  setlength(tempname, strlen(PWideChar(tempname)));
  try
    hOutputFile := CreateFile(PChar(tempname), GENERIC_READ or GENERIC_WRITE,
      FILE_SHARE_READ, CreateInheritable(SecAtrrs), CREATE_ALWAYS,
      FILE_ATTRIBUTE_TEMPORARY, 0);
    if hOutputFile <> INVALID_HANDLE_VALUE then
    begin
      FillChar(StartupInfo, SizeOf(StartupInfo), 0);
      FillChar(ProcessInfo, SizeOf(ProcessInfo), 0);
      StartupInfo.cb := SizeOf(StartupInfo);
      StartupInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
      if Hidden then
        StartupInfo.wShowWindow := SW_HIDE
      else
        StartupInfo.wShowWindow := SW_SHOWNORMAL;
      StartupInfo.hStdError := hOutputFile;
      UniqueString(CommandLine);//in the Unicode version the parameter lpCommandLine needs to be writable
      rz := CreateProcess(nil, PChar(CommandLine), nil, nil, True,
        CREATE_NEW_CONSOLE or NORMAL_PRIORITY_CLASS, nil, nil, StartupInfo,
        ProcessInfo);
      if rz then
      begin
        WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
        GetExitCodeProcess(ProcessInfo.hProcess, result);
        CloseHandle(hOutputFile);
        if result <> 0 then
          StdErr := TFile.ReadAllText(tempname, TEncoding.ASCII);
        CloseHandle(ProcessInfo.hProcess);
        CloseHandle(ProcessInfo.hThread);
      end else
      begin
        CloseHandle(hOutputFile);
        result := 254;
      end;
    end;
  finally
    TFile.Delete(tempname);
  end;
end;


function SignFile(const SignCmdLine:string; const FileName, CrossCert:string; var ResultMessage:string; hidden:boolean=true):boolean;
var
  rz: Cardinal;
  msg: string;
begin
  if pos('/ac',SignCmdLine.ToLower) > 0  then
    rz := CreateDOSProcessRedirected(stringReplace(SignCmdLine, '/ac','/ac "'+CrossCert+'"', [rfIgnoreCase]) + ' "'+FileName+'"', msg, hidden)
  else
    rz := CreateDOSProcessRedirected(SignCmdLine + ' "'+FileName+'"', msg, hidden);
  if rz = 0 then
  begin
    result := true;
    ResultMessage := 'File signed';
  end else
  begin
    result := false;
    ResultMessage := 'Signtool rror code: '+inttostr(rz)+#13#10+msg;
  end;
end;

//**********************************************************************************

procedure TMainForm.btStartClick(Sender: TObject);
begin
  if httpServ.Active then
  begin
    Log('Stopping HTTP server');
    httpServ.Active := false;
  end;

  Log('Trying to sign test file, you MUST enter password for token!');
  if not TrySignFile then
  begin
    pnTop.Color := $8080ff;
    Log('TEST FAILED!!!')
  end
  else
    StartHTTPServer;
end;

procedure TMainForm.FlushLog;
var
  I: Integer;
  fs: TFileStream;
  logname: string;
  rw: RawByteString;
begin
  logname := ChangeFileExt(ParamStr(0),'.log');
  // Open log
  if FileExists(logname) then
  begin
    fs := TFileStream.Create(logname, fmOpenReadWrite or fmShareDenyNone);
    fs.Seek(0, soEnd);
  end
  else
    fs := TFileStream.Create(logname, fmCreate or fmShareDenyNone);
  try
    for I := MainForm.memLog.Lines.Count-1 downto 0 do
    begin
      rw := UTF8Encode(MainForm.memLog.Lines[I]+#13#10);
      fs.Write(rw[1],length(rw));
    end;
  finally
    fs.Free;
  end;
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  SaveSettings;
  FlushLog;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  LoadSettings;
end;

procedure TMainForm.httpServAfterBind(Sender: TObject);
begin
  pnTop.Color := $dbffce;
  Log('HTTP Server started on port:'+httpServ.DefaultPort.ToString);
end;

procedure TMainForm.httpServCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  msg:string;
  tempname: string;
  fs: TFileStream;
begin
  Log('['+AContext.Binding.PeerIP+'] '+ARequestInfo.RawHTTPCommand);
  try
    if (ARequestInfo.Command='GET') and (Pos('/sign', LowerCase(ARequestInfo.Document)) = 1) then
    begin
      if ARequestInfo.Params.Values['file'] <> '' then
      begin
        if FileExists(ARequestInfo.Params.Values['file']) then
        begin
          if SignFile('"'+edSigntoolPath.Text+'" ' +
                      ifthen(ARequestInfo.Params.Values['additional'] <>'', ARequestInfo.Params.Values['additional'], edSigntoolCmdLine.Text),
                      ARequestInfo.Params.Values['file'],
                      edCross.Text,
                      msg) then
          begin
            Log('File "'+ARequestInfo.Params.Values['file']+'" signed');
            AResponseInfo.ResponseNo := 200; // OK
            AResponseInfo.ContentText := '';
            exit;
          end;
        end else
          msg := 'File "'+ARequestInfo.Params.Values['file']+'" not found';

        Log('FAIL TO SIGN: '+msg);
        AResponseInfo.ResponseNo := 200;
        AResponseInfo.CustomHeaders.Values['SignToolErrorCode'] := '1';
        AResponseInfo.ContentText := msg;
        exit;
      end;
    end else if (ARequestInfo.Command='POST') and (Pos('/sign', LowerCase(ARequestInfo.Document)) = 1) then
    begin
      if ARequestInfo.PostStream <> nil then
      begin
        tempname := GetTempFileName('post',ExtractFileExt(ARequestInfo.Params.Values['file']));
//        setlength(tempname, MAX_PATH);
//        GetTempFileName('.','post', 0, @tempname[1]);
//        setlength(tempname, strlen(PWideChar(tempname)));
//        tempname := ChangeFileExt(tempname,ExtractFileExt(ARequestInfo.Params.Values['file']));
        fs := TFileStream.Create(tempname, fmCreate);
        ARequestInfo.PostStream.Position := 0;
        fs.CopyFrom(ARequestInfo.PostStream, ARequestInfo.PostStream.Size);
        fs.Free;

        try
          if SignFile('"'+edSigntoolPath.Text+'" ' +
                      ifthen(ARequestInfo.Params.Values['additional'] <>'', ARequestInfo.Params.Values['additional'], edSigntoolCmdLine.Text),
                      tempname,
                      edCross.Text,
                      msg) then
          begin
            Log('File "'+tempname+'" signed');
            AResponseInfo.ResponseNo := 200; // OK
            AResponseInfo.ServeFile(AContext, tempname);
            exit;
          end;
        finally
          TFile.Delete(tempname);
        end;

        Log('FAIL TO SIGN: '+msg);
        AResponseInfo.ResponseNo := 200;
        AResponseInfo.CustomHeaders.Values['SignToolErrorCode'] := '1';
        AResponseInfo.ContentText := msg;
        exit;
      end;
    end;
  except
    on E: Exception do
    begin
      Log('Exception: '+E.Message);
      AResponseInfo.ResponseNo := 500;
      exit;
    end;
  end;

  Log('BAD REQUEST');
  AResponseInfo.ResponseNo := 400; // Bad req
  AResponseInfo.ContentText := 'Unknown command';
end;

procedure TMainForm.LoadSettings;
var
  ini: TIniFile;
begin
  ini := TIniFile.Create(ChangeFileExt(ParamStr(0),'.ini'));
  try
    edSigntoolPath.Text := ini.ReadString('server', 'signtool_path','signtool.exe');
    edSigntoolCmdLine.Text := ini.ReadString('server', 'signtool_commandline','sign /a "%s"');
    edHttpPort.Text := ini.ReadInteger('server', 'http_port',8090).ToString;
    edCross.Text := ini.ReadString('server','cross_cert','GlobalSign Root CA.crt');
  finally
    ini.Free;
  end;
end;

procedure TMainForm.Log(const AMessage: string);
var
  msg: string;
begin
  msg := DateTimeTostr(now)+' ['+TThread.CurrentThread.ThreadID.ToString+'] '+ AMessage;
  TThread.Queue(nil, procedure
  begin
    if MainForm.memLog.Lines.Count > 20 then
    begin
      try
        FlushLog;
      except
      end;
      MainForm.memLog.Lines.Clear;
    end;
    MainForm.memLog.Lines.Insert(0, msg);
  end);
end;

procedure TMainForm.SaveSettings;
var
  ini: TIniFile;
begin
  ini := TIniFile.Create(ChangeFileExt(ParamStr(0),'.ini'));
  try
    ini.WriteString('server','signtool_path',edSigntoolPath.Text);
    ini.WriteString('server','signtool_commandline',edSigntoolCmdLine.Text);
    ini.WriteInteger('server','http_port',string(edHttpPort.Text).ToInteger);
    ini.WriteString('server','cross_cert',edCross.Text);
  finally
    ini.Free;
  end;
end;

procedure TMainForm.StartHTTPServer;
begin
  httpServ.DefaultPort := string(edHttpPort.Text).ToInteger;
  httpServ.Active := true;
end;

function TMainForm.TrySignFile: boolean;
var
  tryfile: string;
  msg: string;
begin
  result := false;

  if not FileExists(edSigntoolPath.Text) then
  begin
    Log('Error: Signtool.exe not found!');
    exit;
  end;

  tryfile := ChangeFileExt(ParamStr(0),'_try.exe');
  TFile.Copy(ParamStr(0), tryfile, true);

  if not SignFile('"'+edSigntoolPath.Text+'" ' + edSigntoolCmdLine.Text, tryfile, '', msg, false) then
    Log('Error: '+msg)
  else begin
    result := true;
    TFile.Delete(tryfile);
  end;
end;

end.
