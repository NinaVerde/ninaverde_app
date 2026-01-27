# Setup Script for Nina Verde Backup Scheduler
# Run this script once to register the scheduled task.

$TaskName = "NinaVerdeAutoBackup"
$ScriptPath = "C:\Users\adsta\Desktop\Nina Verde\ninaverde_app\scripts\auto_backup.ps1"
$PowershellPath = (Get-Command powershell.exe).Source

# Unregister if exists
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

# Create Action
# We use -ExecutionPolicy Bypass to ensure the script runs even if global policy is restricted
$Action = New-ScheduledTaskAction -Execute $PowershellPath -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""

# Create Triggers
# 12:00 PM
$Trigger1 = New-ScheduledTaskTrigger -Daily -At "12:00PM"
# 6:00 PM
$Trigger2 = New-ScheduledTaskTrigger -Daily -At "06:00PM"
# 12:00 AM (Midnight)
$Trigger3 = New-ScheduledTaskTrigger -Daily -At "12:00AM"

# Register Task
# -User matches current user logic so no password needed for local execution
$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger @($Trigger1, $Trigger2, $Trigger3) -Principal $Principal -Description "Automated 3x Daily Backup for Nina Verde Project"

Write-Host "Task '$TaskName' has been successfully scheduled!"
Write-Host "It will run daily at 12:00 PM, 6:00 PM, and 12:00 AM."
Write-Host "First run will be at the next scheduled interval."
