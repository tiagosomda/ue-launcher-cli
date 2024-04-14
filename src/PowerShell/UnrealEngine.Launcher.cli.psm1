##
# Expected $ue variable format:
# "<unreal-version>" = @{
#       editor = "<path-to>\UnrealEditor.exe";
#       buildTool = "<path-to>\Build.bat";
#       engineAssociation = "<unreal-version (i.e. 5.3) or association guid>"
#     }
#
# Example:
# "5.3" = @{
#       editor = "C:\Program Files\Epic Games\UE_5.3\Engine\Binaries\Win64\UnrealEditor.exe";
#       buildTool = "C:\Program Files\Epic Games\UE_5.3\Engine\Build\BatchFiles\Build.bat";
#       engineAssociation = "537FD5A8-3DAE-4FFC-B347-ACBE0C46D47D"
#     },
# "5.4" = @{
#       editor = "C:\Program Files\Epic Games\UE_5.4\Engine\Binaries\Win64\UnrealEditor.exe";
#       buildTool = "C:\Program Files\Epic Games\UE_5.4\Engine\Build\BatchFiles\Build.bat";
#       engineAssociation = "{9B73BBCE-BE90-4478-B6D4-6EF3325BDD16}"
#     }
##
$ue = @{}

##
# Expected ueProjectList variable format
# $ueProjectList["example-project"] = @{ shortNames = @("ep"); path = "C:\dev\example\Example.uproject" }
##
$ueProjectList = @{}

function Invoke-UE {
    Param
    (
        [Parameter(Mandatory=$false, Position=0)]
        [Alias('ls')]
        [switch] $List,
        [Parameter(Mandatory=$false, Position=0)]
        [Alias('p')]
        [string] $Project,
        [Parameter(Mandatory=$false, Position=0)]
        [Alias('pp')]
        [switch] $PickProject,
        [Parameter(Mandatory=$false, Position=1)]
        [Alias('refresh')]
        [switch] $RefreshProjectFiles,
        [Parameter(Mandatory=$false, Position=1)]
        [Alias('gen')]
        [switch] $GenerateProjectFiles,
        [Parameter(Mandatory=$false, Position=1)]
        [Alias('rm')]
        [switch] $RemoveProjectFiles,
        [Parameter(Mandatory=$false, Position=2)]
        [Alias('u')]
        [switch] $StartUProject,
        [Parameter(Mandatory=$false, Position=2)]
        [Alias('s')]
        [switch] $StartSolution
    )

    $projectFound = $null

    if($List) {
      Show-UEKnownProjects
      return
    }

    if(-not $PickProject -and [string]::IsNullOrEmpty($Project)) {
      Write-Host "No project name given."
      Write-Host "Opening unreal editor launcher ..."
      . $ue.default.editor
      return
    }

    if($PickProject) {
      $projectFound = Select-UEProject      
    } else {
      foreach ($key in $ueProjectList.Keys) {
        $projectItem = $ueProjectList[$key]

        if($key -eq $Project -or $projectItem.shortNames -contains $Project) {
          $projectFound = $projectItem
          $projectFound = $ueProjectList[$key]
          $projectFound.engineAssociation = Get-UEProjectFileEngineAssociation $projectFound.path
          $ueInfo = Get-UEEditorInfo $projectFound.engineAssociation
          $projectFound.engine = $ueInfo.engine
          break;
        }
      }
    }

    if ($projectFound -eq $null) {
      Write-Host "No project found or selected."
      return
    }

    $projectPath = $projectFound.path
    $solutionPath = $projectPath -replace '\.uproject$', '.sln'

    if(-not (Test-Path $projectPath)) {
      Write-Error "projected listed at $projectPath, but file was not found."
      return
    }

    ## default to opening project if no options were passed in
    if($RefreshProjectFiles.IsPresent -eq $false -and $RemoveProjectFiles.IsPresent -eq $false -and $GenerateProjectFiles.IsPresent -eq $false)
    {
      Write-Host "No project operation option passed in. Will attempt to start project." -ForegroundColor Cyan
      $StartSolution = $true
      $StartUProject = $true
    }

    $editorExePath = $ue[$projectFound.engine].editor
    $unrealBuildToolPath = $ue[$projectFound.engine].buildTool
    Write-Host "  Project found: " -ForegroundColor Green
    Write-Host "    Short Names: $($projectFound.shortNames -join ', ')"
    Write-Host "    Path: $projectPath"
    Write-Host "    Engine: $($projectFound.engine)"
    Write-Host "    EngineAssociation: $($projectFound.engineAssociation)"
    Write-Host "  ---"
    Write-Host

  if($RefreshProjectFiles) {
    Write-Host "  Refreshing solution ... " -ForegroundColor Green
    $RemoveProjectFiles = $true
    $GenerateProjectFiles = $true
    Write-Host     
  }

  if($RemoveProjectFiles) {
    Write-Host "  Deleting generated solution ... " -ForegroundColor Green
    $projectFolderPath = Split-Path -Path $projectPath -Parent

    $folderToDelete = @("Binaries", "Intermediate", "Saved")

    foreach ($folderName in $folderToDelete) {
      $folderPath = "$projectFolderPath\$folderName"
      if(Test-Path $folderPath) {
        Write-Host "    Deleting '$folderPath' "
        Get-ChildItem -Path $folderPath -Recurse -Force | Remove-Item -Recurse -Force
        if (-not $?) {
            return
        }
        Remove-Item -Path $folderPath -Recurse -Force
        if (-not $?) {
            return
        }
      } else {
        Write-Host "    Path does not exists $folderPath"  -ForegroundColor Yellow
      }
    }
    Write-Host
  }

  $errorWhileGeneratingSolution = $false
  if($GenerateProjectFiles) {
    Write-Host "  Generating solution files ..." -ForegroundColor Green
    Write-Host "    Build Tool Path: $unrealBuildToolPath"
    Write-Host
    $unrealBuildToolName = (Split-Path -Path $unrealBuildToolPath -Leaf)
    . $unrealBuildToolPath -projectfiles -project="$projectPath" -game -rocket -progress | ForEach-Object { "    $unrealBuildToolName : $_" }

    if ($?) {
        Write-Host "  ---" -ForegroundColor Green
        Write-Host "  Completed" -ForegroundColor Green
        Write-Host
    } else {
        Write-Error "  ---"
        Write-Error "  Completed with errors. See logs above."
        $errorWhileGeneratingSolution = $true
    }
  }

 if($StartUProject) {
    Write-Host "Opening ${key} project ... " -ForegroundColor Green
    Write-Host "  Editor Path: $editorExePath"
    if($errorWhileGeneratingSolution -eq $false) {
      . $editorExePath $projectPath 
    } else {
      Write-Error "Project will not be opened due to errors while generating the project files."
    }
  }

  if($StartSolution) {
    Write-Host "Opening ${key} solution ... " -ForegroundColor Green
    if($errorWhileGeneratingSolution -eq $false) {
      . $solutionPath
    } else {
      Write-Error "Solution will not be opened due to errors while generating the project files."
    }
  }
}

function Update-UEInstallations {
  # Define the root installation path for Unreal Engine
  $installationRoot = "${env:SystemDrive}\Program Files\Epic Games"

  # Get all subdirectories within the installation root
  $engineFolders = Get-ChildItem -Path $installationRoot -Directory | Where-Object { $_.Name -like "UE_*" }

  foreach ($folder in $engineFolders) {
      $version = $folder.Name -replace "UE_", ""
      $editorPath = Join-Path $folder.FullName "Engine\Binaries\Win64\UnrealEditor.exe"
      $buildToolPath = Join-Path $folder.FullName "Engine\Build\BatchFiles\Build.bat"

      # Check if UnrealEditor.exe exists in the folder
      if (Test-Path -Path $editorPath -PathType Leaf) {
          $ue[$version] = @{
              editor = $editorPath
              buildTool = $buildToolPath
              engineAssociation = $version
          }
          $ue.default = $ue[$version]
      }
  }
}

function Select-UEProject {
  $files = Get-ChildItem *.uproject -Recurse -Depth 3
  if($files.Count -eq 1)
  {
    $projectFilePath = $files[0].FullName
    $engineAssociation = Get-UEProjectFileEngineAssociation $projectFilePath 
    if (-not $engineAssociation) {
      Write-Error "unable to retrieve engine association value from '$projectFilePath'"
      return
    }

    $ueInfo = Get-UEEditorInfo $engineAssociation

    $selectedProject = @{ 
        shortNames = @();
        path = $projectFilePath;
        engine = $ueInfo.engine;
        engineAssociation = $engineAssociation
      }
    return $selectedProject
  }
  else 
  {
    $solutions = "`n  Which uproject?: `n`n"
    $count = 0;
    $files | ForEach-Object {
      $solutions += "    $count) " + $_.Name + "`n"
      $count++;
    }

    $solutions += "`n    x) to cancel `n"

    Write-Host $solutions
    $selection = Read-Host -Prompt '  Select one'

    Write-Host "`n"

    if ($selection -match "^[\d\.]+$" -and ($selection -ge 0 -and $selection -le $files.Length -1))
    {
      $index = [int]$selection
      $projectFilePath = $files[$index].FullName
      $engineAssociation = Get-UEProjectFileEngineAssociation $projectFilePath 
      if (-not $engineAssociation) {
        Write-Error "unable to retrieve engine association value from '$projectFilePath'"
        return
      }

      $ueInfo = Get-UEEditorInfo $engineAssociation
      $selectedProject = @{ 
        shortNames = @();
        path = $projectFilePath;
        engine = $ueInfo.engine;
        engineAssociation = $engineAssociation
      }

      return $selectedProject
    }

    return $null
  }
}

function Show-UEKnownProjects {
    Write-Host "Listing known projects:" -ForegroundColor Green
    Write-Host
    foreach ($key in $ueProjectList.Keys) {
      $item = $ueProjectList[$key]
      $item.engineAssociation = Get-UEProjectFileEngineAssociation $item.path
      $ueInfo = Get-UEEditorInfo $item.engineAssociation
      $item.engine = $ueInfo.engine
      Write-Host "  Project: $key" -ForegroundColor Green
      Write-Host "  Short Names: $($item.shortNames -join ', ')"
      Write-Host "  Path: $($item.path)"
      Write-Host "  Engine: $($item.engine)"
      Write-Host "  EngineAssociation: $($item.engineAssociation)"
      Write-Host "  ---"
      Write-Host
    }
}

function Get-UEProjectFileEngineAssociation {
    param (
        [string]$FilePath
    )

    try {
        $jsonContent = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
        $engineAssociation = $jsonContent.EngineAssociation
        return $engineAssociation
    } catch {
        Write-Error "Error reading or parsing the JSON file: $_"
        return $null
    }
}

function Get-UEEditorInfo {
  param (
        [string]$Id
    )

    foreach ($key in $ue.Keys) {
      if($key -eq $Id -or $ue[$key].engineAssociation -eq $Id)
      {
        $result = $ue[$key]
        $result.engine = $key
        return $result 
      }
    }

    return $null
}

function Close-UEInstance {
    param (
        [string]$ProcessNameFilter = $null
    )

    # Get all UnrealEditor processes matching the filter
    $unrealEditorProcesses = Get-Process | Where-Object { ($_.Name -like "*devenv*" -or $_.Name -eq "UnrealEditor") -and $_.CommandLine -like "*$ProcessNameFilter*" }

    # Terminate each process
    foreach ($process in $unrealEditorProcesses) {
        $processId = $process.Id
        $processName = $process.Name
        Write-Host "Stopping process $processName with ID $processId..."
        Stop-Process -Id $processId -Force
    }

    # Wait for processes to exit
    while ($unrealEditorProcesses.Count -gt 0) {
        Start-Sleep -Seconds 1
        $unrealEditorProcesses = Get-Process | Where-Object { $_.Id -in $unrealEditorProcesses.Id }
    }

    Write-Host "All UnrealEditor processes have been terminated."
}

function Remove-UEGeneratedFiles {
    Param(
      [string] $projectFolderPath
    )

    if(-not (Test-Path $projectFolderPath)) {
      Write-Error "Path does not exist at $projectFolderPath " -ForegroundColor Red
      return
    }
    Write-Host "  Deleting generated files at ..." -ForegroundColor Green
    Write-Host "  path: $projectFolderPath "
    

    $folderToDelete = @("Binaries", "Intermediate", "Saved")

    foreach ($folderName in $folderToDelete) {
      $folderPath = "$projectFolderPath\$folderName"
      if(Test-Path $folderPath) {
        Write-Host "    Deleting '$folderPath' "
        Get-ChildItem -Path $folderPath -Recurse -Force | Remove-Item -Recurse -Force
        if (-not $?) {
            return
        }
        Remove-Item -Path $folderPath -Recurse -Force
        if (-not $?) {
            return
        }
      } else {
        Write-Host "    Path does not exists $folderPath"  -ForegroundColor Yellow
      }
    }

    Write-Host
}

Export-ModuleMember -function Invoke-UE, Select-UEProject, Show-UEKnownProjects, `
    Show-UEKnownProjects, Get-UEProjectFileEngineAssociation, Get-UEEditorInfo, `
    Close-UEInstance, Remove-UEGeneratedFiles, Update-UEInstallations `
    -Variable ue, ueProjectList