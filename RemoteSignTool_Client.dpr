program RemoteSignTool_Client;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.IniFiles,
  IdBaseComponent,
  IdComponent,
  IdHTTP,
  signtool_client in 'signtool_client.pas';

var
  client: TRemoteSignToolClient;
  ini: TIniFile;
  filetosign: string;
  additional: string;
  I: Integer;
begin
  try
    ExitCode := 2;
    client := TRemoteSignToolClient.Create;
    try
      ini := TIniFile.Create(ChangeFileExt(ParamStr(0),'.ini'));
      try
        client.host := ini.ReadString('server','host','localhost');
        client.port := ini.ReadInteger('server','port',8090);
      finally
        ini.Free;
      end;

      filetosign := '';
      for I := ParamCount downto 1 do
      begin
        if (filetosign = '') and (length(ParamStr(I)) > 0) and (ParamStr(I)[1] <> '/') and FileExists(ParamStr(I)) then
          filetosign := ParamStr(I)
        else
          if not((I > 2) and (ParamStr(I-1).ToLower = '/ac')) then
            if ParamStr(I).IndexOf(' ') > 0 then
              additional := '"'+ParamStr(I)+'" '+additional
            else
              additional := ParamStr(I)+' '+additional;
      end;

      if filetosign = '' then
      begin
        WriteLn(ErrOutput, 'Error: File not found or not specified');
        WriteLn('You must specify at least file to sign!');
        ExitCode := 1;
        exit;
      end;

      if not client.SignFile(filetosign, additional) then
      begin
        WriteLn(ErrOutput, 'Error: '+client.ErrorMessage);
        ExitCode := client.ErrorCode;
        exit;
      end else
      begin
        WriteLn('File signed succesfully');
        ExitCode := 0;
        exit;
      end;
    finally
      client.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
