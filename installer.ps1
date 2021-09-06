Param (
    [parameter(Mandatory=$true)]
    [string]$productName,
        [bool]$uninstall = $true,
        [bool]$simulate = $true

)

$registryPaths = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"

try {

[Microsoft.Powershell.EditorServices.Extensions.EditorContext]$psEditor.GetEditorContext()

if ($psEditor.GetEditorContext().CurrentFile) {

    $scriptPath = $psEditor.GetEditorContext().CurrentFile.WorkspacePath | Split-Path -Parent

}

} catch {

    if ($psISE) {

    $scriptPath = $psISE.CurrentFile.FullPath | Split-Path -Parent
    
    }
    else {

        $scriptPath = $MyInvocation.MyCommand.Definition | Split-Path -Parent
    }
}


Function PerformInstall {

    $installer = Get-ChildItem -Path $scriptPath 
        
    if ($installer.name -like '*.exe') {
            
        $File = $installer | Where-Object {$_ -match ".exe"}

        write-host $("=" * 80)
        Write-Host "Executing EXE-File $($File) . . ."
        write-host $("=" * 80)
        write-host ""
        
    }elseif ($installer.name -like '*.msi') {
            
        $File = $installer | Where-Object {$_ -match ".msi"} 

        write-host $("=" * 80)
        Write-Host "Executing MSI-File $($File) . . ."
        write-host $("=" * 80)
        write-host ""
    
    }
    
    if($null -eq $file) {

        write-host $("=" * 120)
        Write-Host "No MSI or EXE File found under ScriptPath: $($scriptPath)"
        write-host $("=" * 120)
        write-host ""

        $installerReturnCode = 1

    }else {
        
        if ($installer.name -like '*.exe') {
            
            $installerReturnCode = Start-Process (Join-Path -Path $scriptPath -ChildPath "\$($File)") -PassThru -Wait
        
        }else {
            
        }
    }

    return $installerReturnCode

}

Function PerformUninstall {

    $uninstallKeys = Get-ChildItem -Path $registryPaths | Get-ItemProperty -Name DisplayName, UninstallString, QuietUninstallString -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -like "*$productName*" } 

    foreach($uninstallKey in $uninstallKeys) {
        
        if ($uninstallKey.QuietUninstallString) {
            
            $uninstallString = $uninstallKey.QuietUninstallString.Replace('"', "") 

        }elseif ($uninstallKey.UninstallString) {

            $uninstallString = $uninstallKey.UninstallString.Replace('"', "")   
        
        }
        else {
            
            $uninstallString = "_UNDEFINED_"
        
        }

        if($uninstallString.ToLower().StartsWith("msiexec.exe")) {
            $isMSI = "Yes"
        }
        else {
            $isMSI = "No"
        }

        write-host $("=" * 80)
        write-host "Program Name: $($uninstallKey.DisplayName)"
        write-host "Uninstall String: $uninstallString"
        write-host "MSI Uninstall: $isMSI"
        Write-Host "Uninstall: $uninstall"
        write-host $("=" * 80)
        write-host ""
    
        if ($uninstall) {


            if ($isMSI -eq "No") {
                
                $path_regex = "[a-z]\:\\.*\.exe\s?"
                $switch_regex = "[\-/]\-?[a-z0-9]+\s?"

                $uninsExe = ""
                $uninsSwitches = ""
                
                if ($uninstallString -match $path_regex) { 
                        
                    $uninsExe += $matches[0].TrimEnd()
                    $uninstallString = $uninstallString.Replace($uninsExe,"")
                
                }
                
                if ($uninstallString -match $switch_regex) { 
                    
                    $uninstallString | select-string $switch_regex -allmatches | ForEach-Object {$uninsSwitches += $_.matches.value} | out-null
                
                }

                if ($simulate -eq $true) {

                    if ($uninsSwitches -ne "") {
                        
                        write-host $("=" * 80)
                        write-host "Simulate uninstalling program $($uninstallKey.DisplayName) with EXE $uninsExe $uninsSwitches . . ."
                        write-host "start-process -path `"$uninsExe`" -arg `"$uninsSwitches`""
                        write-host $("=" * 80)
                        write-host ""     

                    }else {  
                        
                        write-host $("=" * 80)
                        write-host "Simulate uninstalling program $($uninstallKey.DisplayName) with EXE $uninsExe . . ."
                        write-host "start-process -path `"$uninsExe`""
                        write-host $("=" * 80)
                        write-host ""
                        
                    }
                    
                }else {

                    write-host $("=" * 80)
                    write-host "Uninstalling program $($uninstallKey.DisplayName) with EXE Uninstall String $uninstallString . . ."
                    write-host $("=" * 80)
                    write-host ""						
                    
                    if ($uninsSwitches -ne "") {
                        
                        write-host "$uninsExe $uninsSwitches"
                        write-host "start-process -path `"$uninsExe`" -arg `"$uninsSwitches`""
                            
                        $uninstallerReturncode = start-process "$uninsExe" -arg "$uninsSwitches" -wait

                    }else {  
                        
                        write-host "$uninsExe"
                        write-host "start-process -path `"$uninsExe`""
                  
                        $uninstallerReturncode = start-process "$uninsExe" -wait 
                        
                    }
                }

            }else {
                
                $msiProductcode = $uninstallString.Split()[1].Replace("/I", "").Replace("/X","")

                if ($simulate -eq $true) {

                    write-host $("=" * 80)
                    write-host "Simulate uninstalling program $($uninstallKey.DisplayName) with MSI Product Code $msiProductcode . . ."
                    Write-Host "Simulate Uninstall... Start-Process `'msiexec.exe`' -ArgumentList `"/x $msiProductcode /quiet`" -PassThru -Wait"
                    write-host $("=" * 80)
                    write-host ""
                    
                }else {

                    write-host $("=" * 80)
                    write-host "Uninstalling program $($uninstallKey.DisplayName) with MSI Product Code $msiProductcode . . ."
                    write-host $("=" * 80)
                    write-host ""

                    $uninstallerReturncode = Start-Process 'msiexec.exe' -ArgumentList "/x $msiProductcode /quiet" -PassThru -Wait

                }

            }

            Write-Host "Uninstall completed. Check programms and features to confirm."

        }else {
            
            
        }

    }

    return $uninstallerReturncode

}


PerformUninstall