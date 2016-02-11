object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Remote SignTool Server'
  ClientHeight = 444
  ClientWidth = 653
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object pnTop: TPanel
    Left = 0
    Top = 0
    Width = 653
    Height = 137
    Align = alTop
    BevelEdges = [beBottom]
    BevelOuter = bvNone
    ParentBackground = False
    TabOrder = 0
    ExplicitWidth = 779
    DesignSize = (
      653
      137)
    object edSigntoolPath: TLabeledEdit
      Left = 16
      Top = 24
      Width = 627
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      EditLabel.Width = 97
      EditLabel.Height = 13
      EditLabel.Caption = 'Path to signtool.exe'
      TabOrder = 0
      Text = 'd:\proj.git\buildtools\signtool.exe'
      ExplicitWidth = 753
    end
    object edHttpPort: TLabeledEdit
      Left = 16
      Top = 107
      Width = 73
      Height = 21
      EditLabel.Width = 48
      EditLabel.Height = 13
      EditLabel.Caption = 'HTTP Port'
      NumbersOnly = True
      TabOrder = 1
      Text = '8090'
    end
    object btStart: TButton
      Left = 507
      Top = 106
      Width = 136
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'Test and start server'
      TabOrder = 2
      OnClick = btStartClick
      ExplicitLeft = 624
    end
    object edSigntoolCmdLine: TLabeledEdit
      Left = 16
      Top = 65
      Width = 627
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      EditLabel.Width = 285
      EditLabel.Height = 13
      EditLabel.Caption = 'Default signtool parameters (if not overridden by client call)'
      TabOrder = 3
      Text = 'sign /sha1 "60BAFCCB504FD648AD39DD18550543BF6A652816" "%s"'
      ExplicitWidth = 753
    end
  end
  object memLog: TMemo
    Left = 0
    Top = 137
    Width = 653
    Height = 307
    Align = alClient
    TabOrder = 1
    ExplicitLeft = 304
    ExplicitTop = 200
    ExplicitWidth = 185
    ExplicitHeight = 89
  end
  object httpServ: TIdHTTPServer
    Bindings = <>
    DefaultPort = 8090
    OnAfterBind = httpServAfterBind
    OnCommandGet = httpServCommandGet
    Left = 32
    Top = 176
  end
end
