program RemoteSignTool_Server;

uses
  Vcl.Forms,
  fmMain in 'fmMain.pas' {MainForm};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
