# Run this PowerShell command once to register a monthly scheduled task
# It will run extractor.py on the 1st of every month at 02:00 AM
$action  = New-ScheduledTaskAction `
    -Execute "C:\codesage\phase1_extract\codesage-env\Scripts\python.exe" `
    -Argument "C:\codesage\phase1_extract\extractor.py" `
    -WorkingDirectory "C:\codesage\phase1_extract"

$trigger = New-ScheduledTaskTrigger -Monthly -DaysOfMonth 1 -At "02:00AM"

$settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable

Register-ScheduledTask `
    -TaskName   "CodeSage Phase1 Monthly Extract" `
    -Action     $action `
    -Trigger    $trigger `
    -Settings   $settings `
    -RunLevel   Highest

# To run it immediately to test:
Start-ScheduledTask -TaskName "CodeSage Phase1 Monthly Extract"

# To check if it ran successfully:
Get-ScheduledTaskInfo -TaskName "CodeSage Phase1 Monthly Extract" |
    Select-Object LastRunTime, LastTaskResult
# LastTaskResult = 0 means success
