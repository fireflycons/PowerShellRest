function Write-EventlogEntry
{
    <#
    .SYNOPSIS
        Write an event to the windows event log or syslog

    .DESCRIPTION
        Write an event to the windows event log or syslog

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

    $evId = [int]$EventId

    # Determine severity based on event ID
    $Severity = $(
        if ($evId -ge 0x20)
        {
            'Error'
        }
        elseif ($evId -ge 0x10)
        {
            'Warning'
        }
        else
        {
            'Information'
        }
    )

    try
    {
        Write-EventLog -LogName Application -Source $SharedVariables.ServerName -EntryType $Severity -EventId $evId -Message $Message
    }
    catch
    {
        # Do nothing
    }
}