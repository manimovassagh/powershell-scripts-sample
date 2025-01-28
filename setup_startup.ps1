# Create a VBS script to run PowerShell elevated
$vbsScript = @'
Set objShell = CreateObject("Shell.Application")
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objFile = objFSO.GetFile(WScript.Arguments(0))
strPath = objFSO.GetParentFolderName(objFile.Path)
strCommand = "powershell.exe -NoExit -Command ""cd 'C:\runner'; .\run.cmd"""
objShell.ShellExecute "powershell.exe", strCommand, "", "runas", 1
'@

# Create paths
$startupFolder = [System.Environment]::GetFolderPath('Startup')
$vbsPath = Join-Path $startupFolder "RunElevatedPowerShell.vbs"

# Create the VBS script
$vbsScript | Out-File -FilePath $vbsPath -Encoding ASCII

# Create a scheduled task (requires running this script as admin once)
$action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbsPath`""
$trigger = New-ScheduledTaskTrigger -AtLogon
$principal = New-ScheduledTaskPrincipal -UserId (Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty UserName) -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 0)

# Register the scheduled task
Register-ScheduledTask -TaskName "RunElevatedPowerShellStartup" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force

# Create a test script to verify the setup
$testScript = @'
Write-Host "Testing elevated privileges..." -ForegroundColor Yellow
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isElevated) {
    Write-Host "Script is running with administrator privileges." -ForegroundColor Green
} else {
    Write-Host "Script is NOT running with administrator privileges." -ForegroundColor Red
}

Write-Host "Current directory: $(Get-Location)" -ForegroundColor Cyan
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
'@

# Save the test script
$testScript | Out-File -FilePath "C:\runner\test_elevation.ps1" -Encoding UTF8
