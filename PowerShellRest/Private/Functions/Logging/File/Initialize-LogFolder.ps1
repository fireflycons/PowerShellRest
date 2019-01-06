function Initialize-LogFolder
{
<#
    .SYNOPSIS
        Initialize logging folder structure

    .DESCRIPTION
        Given a folder path, ensure that path exists and create if necessary.
        Create within it the sub-folders 'HTTP' and 'Error'

    .PARAMETER LogFolder
        Root directory for logs
#>
    param
    (
        [string]$LogFolder
    )

    Write-OperatingSystemLogEntry -EventId ([EventId]::InitializationStep) -Message "Creating logging folders: $LogFolder"

    ($LogFolder, (Join-Path $LogFolder 'HTTP'), (Join-Path $LogFolder 'Error')) |
        ForEach-Object {
        if (-not (Test-Path -Path $_ -PathType Container))
        {
            New-Item -Path $_ -ItemType Directory | Out-Null
        }
    }
}