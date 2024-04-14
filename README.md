# Unreal Engine Launcher CLI
I created this module to help make it easier to regenerate unreal engine projects.  

## Usage:
It has a couple of useful functions
- `Invoke-UE -pp` finds, lists, and interactively waits for you to select a project to open (if only one project, it automatically selects it)
- `Invoke-UE -p blaster` opens known project named 'blaster'
- with either `-pp` or `-p <project name>`, you can also include these options:
  - `-rm` to delete project generated files
  - `-gen` to generate project generated files
  - `-refresh` to first delete and then generate project generated files
  - `-u` opens unreal project
  - `-s` opens visual studio solution
  - `-ls` lists known projects

## Usage in $profile
I have it as part of my powershell `$profile`, here is how I got it setup

```ps1
function Reimport-UELauncherModule {
  $moduleName = "UnrealEngine.Launcher.cli"

  # Reimport the module by first removing (if already loaded) and then importing it 
  if (Get-Module -ListAvailable | Where-Object { $_.Name -eq $moduleName }) {
      Remove-Module $moduleName
  }
  Import-Module "D:\dev\ue-launcher-cli\src\PowerShell\UnrealEngine.Launcher.cli.psd1"
  
  # updates ue installed paths in $ue by searching in the expected paths
  Update-UEInstallations

  # add custom installation directly into the $ue variable
  # or if you want to skip calling Update-UEInstallations, you could list the installed engines here.
  $ue["5.4"] = @{
        editor = "D:\dev\UE\UE_5.4\Engine\Binaries\Win64\UnrealEditor.exe";
        buildTool = "D:\dev\UE\UE_5.4\Engine\Build\BatchFiles\Build.bat";
        engineAssociation = "{9B73BBCE-BE90-4478-B6D4-6EF3325BDD16}"
    }
}
Reimport-UELauncherModule

## my known projects
$ueProjectList["blaster"] = @{ shortNames = @("b"); path = "D:\dev\blaster\src\Blaster\Blaster.uproject" }

function blaster-regen {
  # closes any unreal and visual studio open instances
  Close-UEInstance "Blaster"

  # removes generated files for known plugins
  Remove-UEGeneratedFiles "D:\dev\blaster\src\Blaster\Plugins\MultiplayerSessions"

  # regenerates project files and starts both visual studio and the unreal engine project
  Invoke-UE -p Blaster -refresh -u -s 
}

```

## License
By contributing, you agree that your contributions will be licensed under the same license as this project.

## How to Contribute?
Feel free to fork and create pull requests.

## Questions?

If you have any questions or need clarification, feel free to reach out via GitHub issues or [https://www.tiago.dev](https://www.tiago.dev)