unit signtool_client;

interface

uses System.SysUtils,
     System.Classes,
     idHTTP;

type
  TRemoteSignToolClient = class
  private
    _host: string;
    _port: integer;
    _ErrorMessage: string;
    _ErrorCode: integer;

    http: TIdHTTP;
    procedure SetHost(const Value: string);
    procedure SetPort(const Value: integer);
    procedure ProcessError(const resultStream: TStream);
  public
    constructor Create;
    destructor Destroy; override;

    function SignFile(const FileName, Additional: string):boolean;

    property Host:string read _Host write SetHost;
    property Port:integer read _Port write SetPort;
    property ErrorMessage: string read _ErrorMessage;
    property ErrorCode: integer read _ErrorCode;
  end;

implementation

uses
  System.NetEncoding,
  System.StrUtils,
  System.IOUtils,
  Windows;

{ TRemoteSignToolClient }

constructor TRemoteSignToolClient.Create;
begin
  inherited;
  http := TidHTTP.Create(nil);
  http.HandleRedirects := true;
end;

destructor TRemoteSignToolClient.Destroy;
begin
  http.Free;
  inherited;
end;

procedure TRemoteSignToolClient.SetHost(const Value: string);
begin
  _host := Value;
end;

procedure TRemoteSignToolClient.SetPort(const Value: integer);
begin
  _port := Value;
end;

procedure TRemoteSignToolClient.ProcessError(const resultStream: TStream);
var
  rdr: TStreamReader;
begin
  if resultStream <> nil then
  begin
    rdr := TStreamReader.Create(resultStream);
    resultStream.Position := 0;
    _ErrorMessage := rdr.ReadToEnd;
    rdr.Free;
  end else
    _ErrorMessage := '';
end;

function TRemoteSignToolClient.SignFile(const FileName,
  Additional: string): boolean;
var
  resultStream: TStream;
  tempname: string;
begin
  _ErrorMessage := '';
  _ErrorCode := 0;
  result := false;
  resultStream := nil;
  try
    if SameText(_Host,'localhost') or SameText(_Host,'127.0.0.1') then
    begin
      try
        // Get query used for signing locally, when server side on same computer
        http.Get('http://'+_Host+':'+inttostr(_Port)+
                 '/sign?file='+TNetEncoding.HTML.Encode(FileName)+
                 ifthen(Additional<>'','&additional='+TNetEncoding.HTML.Encode(Additional),''),
                 resultStream);
        if http.Response.RawHeaders.Values['SignToolErrorCode'] <> '' then
        begin
          _ErrorCode := strtointdef(http.Response.CustomHeaders.Values['SignToolErrorCode'],1);
          ProcessError(resultStream);
        end else
          result := true;
      except
        _ErrorCode := http.ResponseCode;
        _ErrorMessage := http.ResponseText;
      end;
    end else
    begin
      setlength(tempname, MAX_PATH);
      GetTempFileName('.','cli', 0, @tempname[1]);
      setlength(tempname, strlen(PWideChar(tempname)));

      resultStream := TFileStream.Create(tempname, fmCreate);
      try
        // Send file via POST query, result must be signed file
        http.Post('http://'+_Host+':'+inttostr(_Port)+
                 '/sign?file='+TNetEncoding.HTML.Encode(FileName)+
                 ifthen(Additional<>'','&additional='+TNetEncoding.HTML.Encode(Additional),''),
                 FileName, resultStream);
        if http.Response.RawHeaders.Values['SignToolErrorCode'] <> '' then
        begin
          _ErrorCode := strtointdef(http.Response.CustomHeaders.Values['SignToolErrorCode'],1);
          ProcessError(resultStream);
        end else begin
          FreeAndNil(resultStream);// Unlock result file
          try
            TFile.Copy(tempname, FileName, true);
            result := true;
          except
            _ErrorCode := 2;
            _ErrorMessage := SysErrorMessage(GetLastError);
          end;
        end;
      except
        _ErrorCode := http.ResponseCode;
        _ErrorMessage := http.ResponseText;
      end;

    end;
  finally
    resultStream.Free;
    if tempname <> '' then
      TFile.Delete(tempname);
  end;
end;

end.
