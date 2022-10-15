unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.IOUtils, FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, PyEnvironment,
  PythonEngine, PyEnvironment.Embeddable, PyEnvironment.Distribution,
  PyEnvironment.Embeddable.Res, PyEnvironment.Embeddable.Res.Python39,
  FMX.Memo.Types, FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo,
  FMX.PythonGUIInputOutput, PyCommon, PyModule, PyPackage, PSUtil, FMX.StdCtrls,
  PyTorch, PyEnvironment.AddOn, PyEnvironment.AddOn.GetPip,
  PyEnvironment.AddOn.EnsurePip;

type
  // A helper class to make installing Torch GPU easier
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
    Button2: TButton;
    InstallForGPU: TSwitch;
    Label1: TLabel;
    GetPip: TPyEnvironmentAddOnGetPip;
    procedure FormCreate(Sender: TObject);
    procedure PyEmbedAfterSetup(Sender: TObject; const APythonVersion: string);
    procedure PyEmbedAfterActivate(Sender: TObject;
      const APythonVersion: string; const AActivated: Boolean);
    procedure PackageAfterInstall(Sender: TObject);
    procedure PackageAfterImport(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Log(const AMsg: String);
    procedure PyEmbedBeforeSetup(Sender: TObject; const APythonVersion: string);
    procedure Button2Click(Sender: TObject);
    procedure PackageInstallError(Sender: TObject; AErrorMessage: string);
    procedure GetPipExecute(const ASender: TObject;
      const ATrigger: TPyEnvironmentaddOnTrigger;
      const ADistribution: TPyDistribution);
    procedure GetPipExecuteError(const ASender: TObject;
      const ADistribution: TPyDistribution; const AException: Exception);
  private
    { Private declarations }
    PythonIsActivated: Boolean;
    PythonPath: String;
    procedure SetPythonSetupButtonText;
    procedure AddPythonPackages;
    procedure Test;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

const
  JSONFileName: String  = 'python.json'; // For Future Use
  AppName: String  = 'SimplePython'; // For Future Use
  // We're using Python 3.9 owing to SOME packages having issues with
  // 3.10. Note that issues with 3.10 are rare and indeed this demo
  // actually works fine with it (but one future one won't - so 3.9)
  PyVersion: String  = '3.9';
  // The URL of the GPU version of PyTorch available from
  // https://pytorch.org/get-started/locally/ by selecting
  // PIP and the latest CUDA version
  TorchGPUAddress: String = 'https://download.pytorch.org/whl/cu116';

implementation

{$R *.fmx}

uses
// These uses are for the TPipOptHelp Helper
  PyPackage.Manager.Defs, PyPackage.Manager.Defs.Pip;

// Initialise important stuff
procedure TForm1.FormCreate(Sender: TObject);
begin
  // Default to not letting the user delete Python
  Button2.Enabled := False;
  // Store the directory Python will be installed into (optionaly
  // really but used here + there for illustration)
  PythonPath := TPath.Combine(PyEmbed.EnvironmentPath, PyEmbed.PythonVersion);
  // Set form Caption
  Caption := 'Using Embedded Python';
  // Set the text of Button1 depending on whether we've installed
  // Python yet or not
  SetPythonSetupButtonText;
end;

// Show if we updated the pre-packaged PIP

procedure TForm1.GetPipExecute(const ASender: TObject;
  const ATrigger: TPyEnvironmentaddOnTrigger;
  const ADistribution: TPyDistribution);
begin
  Log('');
  Log('Updated PIP');
end;

// Show if we updating PIP went wrong
procedure TForm1.GetPipExecuteError(const ASender: TObject;
  const ADistribution: TPyDistribution; const AException: Exception);
begin
  Log('PIP Exception ');
  Log('Class : ' + AException.ClassName);
  Log('Error : ' + AException.Message);
end;

// This is a helper to simplify passing an ExtraIndexURL parameter to
// a package (especially useful with Torch as it can allow GPU support)
procedure TPipOptHelp.ExtraIndexUrl(const AURL: String);
begin
  TPyPackageManagerDefsPip(Managers.Pip).InstallOptions.ExtraIndexUrl := AUrl;
end;

// Just shortening multiple lines of Memo1.Lines.Add(...)
procedure TForm1.Log(const AMsg: String);
begin
  Memo1.Lines.Add(AMsg);
  Application.ProcessMessages;
end;

// Change Button1's text based on whether Python is installed
procedure TForm1.SetPythonSetupButtonText;
begin
  // PythonPath is where Python gets installed - if it's missing then
  // we need to install it otherwise we can run some Python
  if not DirectoryExists(PythonPath) then
    Button1.Text := 'Install Python'
  else
    begin
      Button1.Text := 'Run Python';
      // Only allow the deletion of Python if we're not using it
      if not PythonIsActivated then
        Button2.Enabled := True;
    end;
end;

// This will delete teh Python installation which is useful for
// testing with vs without GPU etc (uninstalling and re-installing
// a package would be better but that's for later)
procedure TForm1.Button2Click(Sender: TObject);
begin
  Button1.Enabled := False;
  Button2.Enabled := False;
  Application.ProcessMessages;
  // Delete Python
  TDirectory.Delete(PythonPath, True);
  // Refresh Button1 text
  SetPythonSetupButtonText;
  Button1.Enabled := True;
end;

// If Python isn't installed then installk it otherwise just run
// the Python code
procedure TForm1.Button1Click(Sender: TObject);
begin
  Memo1.Lines.Clear;
  Button1.Enabled := False;
  Button2.Enabled := False;
  // PythonIsActivated is set to True after we run the setup
  // so first run we always try a setup
  if not PythonIsActivated then
    begin
      // Call the python setup function - it'll do very little
      // if everything is already installed
      PyEmbed.Setup(PyEmbed.PythonVersion);
      if not PythonIsActivated then
        ShowMessage('Python was not set up');
    end
  else
    begin
      // This code is only called if we're run the setup code
      Test;
      Button1.Enabled := True;
    end;
end;

procedure TForm1.PyEmbedAfterSetup(Sender: TObject;
  const APythonVersion: string);
begin
  Log('Installed Python');
  if PyEmbed.Activate(PyEmbed.PythonVersion) then
    begin
      // Add any Python Packages we want to use in our code
      AddPythonPackages;
    end
  else
    Log('Python could not be activated');
end;

// Show we're setting Python up
procedure TForm1.PyEmbedBeforeSetup(Sender: TObject;
  const APythonVersion: string);
begin
  Log('Setting up Python');
end;

// Show Python is active
procedure TForm1.PyEmbedAfterActivate(Sender: TObject;
  const APythonVersion: string; const AActivated: Boolean);
begin
  Log('Python is active');
end;

// Install and Import any packages we want to use
// Note that Import is only required if you want to
// use a package from Delphi. If you only need a to
// use a package from Python code then Import is
// not necessary (but here we're showing both so
// Import is required for the Test procedure)
procedure TForm1.AddPythonPackages;
begin
  // If the user wants to install GPU support then PIP
  // needs the URL of the Torch distribution.
  if InstallForGPU.IsChecked then
    PyTorch1.ExtraIndexUrl(TorchGPUAddress);
  Log('Installing Torch');
  // Install Torch (An AI library)
  PyTorch1.Install;
  Log('Importing Torch');
  // Import Torch so we can use it from within Delphi in 'Test'
  PyTorch1.Import;

  Log('Installing PSUtil');
  // Install PSUtil (A system information library)
  PSUtil.Install;
  Log('Importing PSUtil');
  // Import PSUtil so we can use it from within Delphi in 'Test'
  PSUtil.Import;

  // Set PythonIsActivated so Button1 can say the right thing
  PythonIsActivated := True;
  // Update Button1
  SetPythonSetupButtonText;
  Log('');
  // Run some test code
  Test;
  Button1.Enabled := True;
end;

// Show we imported some package
procedure TForm1.PackageAfterImport(Sender: TObject);
begin
  Log('Imported ' + TPyPackage(Sender).PyModuleName);
end;

// Show we installed some package
procedure TForm1.PackageAfterInstall(Sender: TObject);
begin
  Log('Installed ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.PackageInstallError(Sender: TObject; AErrorMessage: string);
begin
  Log('Installation Error for ' + TPyPackage(Sender).PyModuleName + ' :' + sLineBreak + AErrorMessage);
end;

// Some simple test Python + Delphi using Python packages
procedure TForm1.Test;
var
  SomeCode: TStringList;
  cores: Variant;
  threads: Variant;
  memory: Variant;
  gpu_count: Variant;
  I: Integer;
begin
  Log('Some simple Python...');
  // Create a StringList to hold some test Python code
  SomeCode := TStringList.Create;
  try
    // Add the Python code to the StringList
    // We could optionally store this in an external
    // file and use SomeCode.LoadFromFile(...) as
    // this is what you would usually do
    SomeCode.Add('import sys');
    SomeCode.Add('import io');
    SomeCode.Add('import pip');
    SomeCode.Add('print("Python is", sys.version)');
    SomeCode.Add('print("PIP version is ", pip.__version__)');
    SomeCode.Add('print("Python''s library paths are...")');
    SomeCode.Add('for p in sys.path:');
    SomeCode.Add('  print(p)');

    // Run the Python code
    PyEng.ExecStrings(SomeCode);

  finally
    // Free the StringList
    SomeCode.Free;
  end;

  // Only do this is PSUtil imported OK
  if PSUtil.IsImported then
    begin
      Log('');

      // These lines call the Python PSUtil module and
      // store the returned values so we can do something
      // with them
      cores := PSUtil.psutil.cpu_count(False);
      threads := PSUtil.psutil.cpu_count(True);
      memory := PSUtil.psutil.virtual_memory();

      // Print out the information PSUtil told us about
      // the PC we're running this cofe on
      Log('Show some info from PSUtil...');
      Log('PSUtil says this PC has ' +
        cores + ' cores, ' +
        threads + ' threads' +
        ' and ' + Format('%3.2f', [Single(memory.total) / (1024 * 1024 * 1024)])+ ' GB of available memory');
    end
  else
    Log('PSUtil not imported');

  // Only do this is Torch imported OK
  if PyTorch1.IsImported then
    begin
      Log('');

      // This will get the number of GPUs this PC has
      // It will simply return zero if we didn't install
      // the GPU version of PyTorch
      gpu_count := PyTorch1.torch.cuda.device_count();
      Log('Torch returned gpu_count = ' + gpu_count);

      // If we installed the GPU version of PyTorch AND this
      // PC has one or more NVidia GPUs then we can print out
      // some information about the GPU(s)
      // FYI...
      // Apple is supported on M1 or better Macs but the code is different
      // AMD has very limited support and only under Linux (code unchanged)
      if gpu_count > 0 then
        begin
          Log('');
          for I := 0 to gpu_count - 1 do
            begin
              if I > 0 then
                Log('');
              Log('GPU #' + IntToStr(I));
              // This stores a load of information about the currently
              // selected GPU so we can prit it out
              var gpu_props: Variant := PyTorch1.torch.cuda.get_device_properties(I);

              Log('Torch returned Name = ' + gpu_props.name);
              Log('Torch returned CudaMajor = ' + gpu_props.major);
              Log('Torch returned CudaMinor = ' + gpu_props.minor);
              Log('Torch returned Memory = ' + gpu_props.total_memory);
              Log('Torch returned CUs = ' + gpu_props.multi_processor_count);
            end;
        end;
    end
  else
    Log('Torch not imported');

end;

end.
