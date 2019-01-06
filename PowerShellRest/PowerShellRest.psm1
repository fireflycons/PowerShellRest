<#
    REST server module.

    Takes as a module argument the path to a folder from which to dot-source controller classes.

    We load up and validate all the controller classes as part of module load.
    There's no real point in having a function to do it after load as PowerShell classes, once defined,
    remain until the session is closed. Removing the module will not get rid of the classes.
    This is because they are genuine .NET classes and become resident in the session's AppDomain.
#>

#Requires -Version 5.1
Set-StrictMode -Version Latest

$ErrorActionPreference = 'Stop'

# Load assemblies we will need
('System.Web', 'System.Collections.Specialized', 'System.IO.Compression') |
    ForEach-Object {
    [System.Reflection.Assembly]::LoadWithPartialName($_) | Out-Null
}

# A UTF8 encoding without BOM for log writing
$script:UTF8Encoding = [System.Text.UTF8Encoding]::new($false)

# Look for shared variable hash and create if not present
if (-not (Get-Item variable:SharedVariables -ErrorAction SilentlyContinue))
{
    $initvars = @{
        ServerName    = [IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
        ServerVersion = [Version]'0.0'
        IsPester      = $null -ne (Get-PSCallStack | Where-Object { $_.Command -ieq 'Invoke-Pester' }) -or (Test-Path -Path Env:\Pester)
        CanLogEvents  = $false
        LoggingQueue  = [System.Collections.Concurrent.BlockingCollection[System.Collections.Generic.KeyValuePair[string, string]]]::new(
            [System.Collections.Concurrent.ConcurrentQueue[System.Collections.Generic.KeyValuePair[string, string]]]::new()
        )
    }

    Set-Variable -Scope Global -Name SharedVariables -Value ([hashtable]::Synchronized($initvars))
}

# Look for user classes
$script:Plugins = $(

    if ($args)
    {
        # User class directory set by Import-Module arguments.
        # Should really only use this when testing/running under Pester.
        $args
    }
    elseif (Get-Item variable:IssPluginDir -ErrorAction SilentlyContinue)
    {
        # User class directory set by runspace initial session state.
        # Indicates the module has been loaded into a runspace pool for normal operation.
        $IssPluginDir
    }

    # else
    # Module has been imported with no arguments.
    # This is the case when initially starting for normal operation
    # and before runspace pools have been created by Start-RestServer.
)

try
{
    # Get public and private function definition files.
    $Public = Get-ChildItem -Path (Join-Path $PSScriptRoot Public) -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue | Sort-Object -Property Name
    $Private = Get-ChildItem -Path (Join-Path $PSScriptRoot Private) -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue  | Sort-Object -Property Name

    # Get user controller code
    $LoadPlugins = $script:Plugins |
        Where-Object {
        -not [string]::IsNullOrEmpty($_) -and (Test-Path -Path $_ -PathType Container)
    } |
        ForEach-Object {

        Get-ChildItem -Path $_ -Recurse -File -Filter *.ps1 -ErrorAction SilentlyContinue
    }

    # Dot source the files
    foreach ($import in @($Private + $Public + $LoadPlugins))
    {
        . $import.FullName
    }

    $SharedVariables.CanLogEvents = Initialize-EventLogging

    if ($script:Plugins)
    {
        $script:ControllerTable = New-ControllerTable

        # If there's no routes defined, exit
        if (($script:ControllerTable | Measure-Object).Count -eq 0)
        {
            throw 'No routes defined.'
        }
    }
    else
    {
        $script:ControllerTable = $null
    }

}
catch
{
    $msg = "Module Load:`n$($_.Exception.Message)`n$($_.ScriptStacktrace)"

    if ([System.Environment]::UserInteractive -and -not $SharedVariables.IsPester)
    {
        Write-Host -ForegroundColor Red $msg
    }
    try
    {
        Write-OperatingSystemLogEntry -EventId ([EventId]::Fatal) -Message $msg
    }
    catch
    {
        # Do nothing
    }
    throw
}

Export-ModuleMember -Function ($Public | Select-Object -ExpandProperty Basename)
