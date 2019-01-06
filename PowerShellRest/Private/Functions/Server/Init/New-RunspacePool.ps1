function New-RunspacePool
{
<#
    .SYNOPSIS
        Create a runspace pool o9f threads for servicing requests

    .PARAMETER MaxThreads
        Maximum number of threads to run

    .PARAMETER ClassPath
        List of paths to use controller code.

    .OUTPUTS
        Configured runspace pool
#>
    param
    (
        [int]$MaxThreads,
        [string[]]$ClassPath
    )

    Write-OperatingSystemLogEntry -EventId ([EventId]::InitializationStep) -Message "Creating request handler runspace pool with $MaxThreads threads."

    $usingModules = $null
    $usingModules = Get-ModuleDependencies -ClassPath $ClassPath

    # Define the initial session state for a pool:
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows))
    {
        $iss.ApartmentState = 'STA'
    }

    $iss.ThreadOptions = 'ReuseThread'

    # Global variables defined in each thread
    $iss.Variables.Add(([System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('IssPluginDir', $ClassPath, 'Path to load user classes from')))
    $iss.Variables.Add(([System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('SharedVariables', $SharedVariables, 'Thread shared variables')))

    # Import this module
    $modulePath = Split-Path -Parent $MyInvocation.MyCommand.Module.Path

    $iss.ImportPSModulesFromPath($modulePath)

    # Import user-requested modules
    if ($usingModules -and @($usingModules).Length -gt 0)
    {
        # These must be installed modules
        $iss.ImportPSModule($usingModules)
    }

    $pool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool($MaxThreads, $MaxThreads, $iss, $Host)
    $pool.Open()

    Write-OperatingSystemLogEntry -EventId ([EventId]::InitializationStep) -Message "Runspace pool creation complete."

    $pool
}