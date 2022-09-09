unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.IOUtils, FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, PyEnvironment,
  PyEnvironment.Local, PythonEngine, PyEnvironment.Embeddable,
  PyEnvironment.Embeddable.Res, PyEnvironment.Embeddable.Res.Python39,
  FMX.Memo.Types, FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo,
  FMX.PythonGUIInputOutput, PyCommon, PyModule, PyPackage, PSUtil, FMX.StdCtrls;

type
  TForm1 = class(TForm)
    PyEng: TPythonEngine;
    PyIO: TPythonGUIInputOutput;
    Memo1: TMemo;
    PSUtil: TPSUtil;
    PyEmbed: TPyEmbeddedResEnvironment39;
    Panel1: TPanel;
    Button1: TButton;
    procedure PyEmbedAfterActivate(Sender: TObject;
      const APythonVersion: string; const AActivated: Boolean);
    procedure PSUtilAfterImport(Sender: TObject);
    procedure PSUtilAfterInstall(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure PyEmbedAfterSetup(Sender: TObject; const APythonVersion: string);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  procedure Test;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

procedure TForm1.Test;
var
  SomeCode: TStringList;
  cores: Variant;
  threads: Variant;
  memory: Variant;
begin
  Memo1.Lines.Add('');
  Memo1.Lines.Add('Some simple Python...');
  SomeCode := TStringList.Create;
  try
    SomeCode.Add('import sys');
    SomeCode.Add('import io');
    SomeCode.Add('for p in sys.path:');
    SomeCode.Add('  print(p)');

    PyEng.ExecString(SomeCode.Text);

  finally
    SomeCode.Free;
  end;

  if PSUtil.IsImported then
    begin
      Memo1.Lines.Add('');

      cores := PSUtil.psutil.cpu_count(False);
      threads := PSUtil.psutil.cpu_count(True);
      memory := PSUtil.psutil.virtual_memory();

      Memo1.Lines.Add('Show some info from PSUtil...');
      Memo1.Lines.Add('PSUtil says this PC has ' +
        cores + ' cores, ' +
        threads + ' threads' +
        ' and ' + memory.total + ' bytes or memory');
    end;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  PyEmbed.Setup(PyEmbed.PythonVersion);
end;

procedure TForm1.PyEmbedAfterSetup(Sender: TObject;
  const APythonVersion: string);
begin
  PyEmbed.Activate(PyEmbed.PythonVersion);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  // This needs changing when LocalEnvironment works - it's only cosmetic anyway
  if DirectoryExists(TPath.Combine(PyEmbed.EnvironmentPath, PyEmbed.PythonVersion)) then
    Button1.Text := 'Run Python'
  else
    Button1.Text := 'Setup Python';

end;

procedure TForm1.PSUtilAfterImport(Sender: TObject);
begin
  Memo1.Lines.Add('PSUtil has imported');
  Test;
end;

procedure TForm1.PSUtilAfterInstall(Sender: TObject);
begin
  Memo1.Lines.Add('PSUtil has installed');
end;

procedure TForm1.PyEmbedAfterActivate(Sender: TObject;
  const APythonVersion: string; const AActivated: Boolean);
var
  SomeCode: TStringList;
begin
  Memo1.Lines.Add('Python is active');
  if Not PSUtil.IsInstalled then
    PSUtil.Install;
  PSUtil.Import;
end;

end.
