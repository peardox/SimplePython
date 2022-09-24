unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.IOUtils, FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, PyEnvironment,
  PythonEngine, PyEnvironment.Embeddable,
  PyEnvironment.Embeddable.Res, PyEnvironment.Embeddable.Res.Python39,
  FMX.Memo.Types, FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo,
  FMX.PythonGUIInputOutput, PyCommon, PyModule, PyPackage, PSUtil, FMX.StdCtrls,
  PyTorch, PyEnvironment.AddOn, PyEnvironment.AddOn.GetPip,
  PyPackage.Manager.Defs, PyPackage.Manager.Defs.Pip;

type
  TPipOptHelp = class Helper for TPyManagedPackage
    procedure ExtraIndexUrl(const AURL: String);
  end;

  TForm1 = class(TForm)
    PyEng: TPythonEngine;
    PyIO: TPythonGUIInputOutput;
    Memo1: TMemo;
    PSUtil: TPSUtil;
    PyEmbed: TPyEmbeddedResEnvironment39;
    Panel1: TPanel;
    Button1: TButton;
    PyTorch1: TPyTorch;
    PyEnvironmentAddOnGetPip1: TPyEnvironmentAddOnGetPip;
    procedure FormCreate(Sender: TObject);
    procedure PyEmbedAfterSetup(Sender: TObject; const APythonVersion: string);
    procedure PyEmbedAfterActivate(Sender: TObject;
      const APythonVersion: string; const AActivated: Boolean);
    procedure PackageAfterInstall(Sender: TObject);
    procedure PackageAfterImport(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Log(const AMsg: String);
  private
    { Private declarations }
    PyIsActivated: Boolean;
    procedure Test;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

const
  JSONFileName = 'python.json';
  AppName = 'SimplePython';
  PyVersion = '3.9';

implementation

{$R *.fmx}

procedure TPipOptHelp.ExtraIndexUrl(const AURL: String);
begin
  TPyPackageManagerDefsPip(Managers.Pip).InstallOptions.ExtraIndexUrl := AUrl;
end;

procedure TForm1.Log(const AMsg: String);
begin
  Memo1.Lines.Add(AMsg);
  Application.ProcessMessages;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Caption := 'Using Embedded Python';
  PyIsActivated := False;
  // This is a bit naff - it's only cosmetic anyway
  if DirectoryExists(TPath.Combine(PyEmbed.EnvironmentPath, PyEmbed.PythonVersion)) then
    Button1.Text := 'Run Python'
  else
    Button1.Text := 'Setup Python';
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  Button1.Enabled := False;
  if not PyIsActivated then
    begin
      PyEmbed.Setup(PyEmbed.PythonVersion);
      if not PyIsActivated then
        ShowMessage('Python was not set up');
      Button1.Text := 'Run Python';
    end
  else
    Test;
  Button1.Enabled := True;
end;

procedure TForm1.PyEmbedAfterSetup(Sender: TObject;
  const APythonVersion: string);
begin
  if not PyEmbed.Activate(PyEmbed.PythonVersion) then
    Log('Python could not be activated');
end;

procedure TForm1.PyEmbedAfterActivate(Sender: TObject;
  const APythonVersion: string; const AActivated: Boolean);
begin
  Log('Python is active');
  if Not PyTorch1.IsInstalled then
    begin
      PyTorch1.ExtraIndexUrl('https://download.pytorch.org/whl/cu116');
      PyTorch1.Install;
    end
  else
    PyTorch1.Import;
  if Not PSUtil.IsInstalled then
    PSUtil.Install
  else
    PSUtil.Import;
  PyIsActivated := True;
  Test;
end;

procedure TForm1.PackageAfterImport(Sender: TObject);
begin
  Log('Imported ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.PackageAfterInstall(Sender: TObject);
begin
  Log('Installed ' + TPyPackage(Sender).PyModuleName);
  TPyPackage(Sender).Import;
end;

procedure TForm1.Test;
var
  SomeCode: TStringList;
  cores: Variant;
  threads: Variant;
  memory: Variant;
  I: Integer;
begin
  Log('');
  Log('Some simple Python...');
  SomeCode := TStringList.Create;
  try
    SomeCode.Add('import sys');
    SomeCode.Add('import io');
    SomeCode.Add('print("Python is", sys.version)');
    SomeCode.Add('print("Python''s library paths are...")');
    SomeCode.Add('for p in sys.path:');
    SomeCode.Add('  print(p)');

    PyEng.ExecString(SomeCode.Text);

  finally
    SomeCode.Free;
  end;

  if PSUtil.IsImported then
    begin
      Log('');

      cores := PSUtil.psutil.cpu_count(False);
      threads := PSUtil.psutil.cpu_count(True);
      memory := PSUtil.psutil.virtual_memory();

      Log('Show some info from PSUtil...');
      Log('PSUtil says this PC has ' +
        cores + ' cores, ' +
        threads + ' threads' +
        ' and ' + Format('%3.2f', [Single(memory.total) / (1024 * 1024 * 1024)])+ ' GB of available memory');
    end
  else
    Log('PSUtil not imported');

  if PyTorch1.IsImported then
    begin
      Log('');

      var gpu_count: Variant := PyTorch1.torch.cuda.device_count();
      var mps_available: Variant := PyTorch1.torch.backends.mps.is_available();
      Log('Torch returned gpu_count = ' + gpu_count);
      Log('Torch returned MPS = ' + mps_available);
      if gpu_count > 0 then
        begin
          for I := 0 to gpu_count - 1 do
            begin
              var gpu_props: Variant := PyTorch1.torch.cuda.get_device_properties(I);

              Log('Torch returned Name = ' + gpu_props.name);
              Log('Torch returned CudaMajor = ' + gpu_props.major);
              Log('Torch returned CudaMajor = ' + gpu_props.minor);
              Log('Torch returned Memory = ' + gpu_props.total_memory);
              Log('Torch returned CUs = ' + gpu_props.multi_processor_count);
            end;
        end;
    end
  else
    Log('Torch not imported');

end;

end.
