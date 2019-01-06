function Write-OperatingSystemLogEntry
{
<#
    .SYNOPSIS
        Write an entry to the operating system log

    .DESCRIPTION
        Write an entry to the operating system log:
        Windows - Event Log
        Unix/Linux - syslog

    .PARAMETER EventId
        Event ID for log

    .PARAMETER Message
        Message to log
#>
    param
    (
        [EventId]$EventId,

        [Parameter(Position = 0)]
        [string]$Message
    )

    if (-not ($SharedVariables.CanLogEvents))
    {
        return
    }

    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows))
    {
        Write-EventlogEntry -EventId $EventId -Message $Message
    }
    else
    {
        Write-SyslogEntry -EventId $EventId -Message $Message
    }
}