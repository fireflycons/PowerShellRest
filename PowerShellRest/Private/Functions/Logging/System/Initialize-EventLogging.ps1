function Initialize-EventLogging
{
    <#
    .SYNOPSIS
        Windows - Init event logging, creating the log source if needed.
        Unix/Linux - Assume syslog is always present

    .DESCRIPTION
        Creates or opens the event logging source for the application.
        If the event source does not exist, the caller must have sufficient rights to create an event source.
        If the account you intend to run the service as does not have these rights, load the module in
        a console session as Administrator and this will create the log.

    .OUTPUTS
        True if the event log is available for use; else False
#>
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows))
    {
        # On Windows...

        # Has log already been created?
        if ([System.Diagnostics.EventLog]::SourceExists($SharedVariables.ServerName))
        {
            # Yes
            return $true
        }

        try
        {
            # Try to create
            $log = New-EventLog -LogName Application -Source $SharedVariables.ServerName
            return $true
        }
        catch
        {
            Write-Warning "Unable to create application event log $($SharedVariables.ServerName): $($_.Exception.Message)"
            Write-Warning "Import the module once in a console session As Administrator to create event source."
        }

        return $false
    }
    else
    {
        # Syslog should always be available
        return $true
    }
}