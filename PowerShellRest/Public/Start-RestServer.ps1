function Start-RestServer
{
    <#
    .SYNOPSIS
        Starts the REST server

    .DESCRIPTION
        This is the main method for starting up a new server.

    .PARAMETER BoundIp
        IP address to bind listener to. Default 0.0.0.0 (all host interfaces)

    .PARAMETER Port
        Port number to listen on.

    .PARAMETER LogFolder
        Root folder for logs. Subdirectories 'HTTP' and 'Error' will be created within

    .PARAMETER SingleThreaded
        If set, start server in single threaded mode

    .PARAMETER ThreadCount
        Number of request processing threads to start.

    .PARAMETER Service
        If set, run in service mode. If not set, server will be single threaded and exit after processing the first request.
#>
    [CmdletBinding(DefaultParameterSetName = 'MultiThreaded')]
    param
    (
        [string[]]$ClassPath, # unused

        [ValidatePattern('^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')]
        [string]$BoundIp = '0.0.0.0',

        [UInt16]$Port,

        [string]$LogFolder = ((Get-Location).Path),

        [Parameter(ParameterSetName = 'SingleThreaded')]
        [switch]$SingleThreaded,

        [Parameter(ParameterSetName = 'MultiThreaded')]
        [int]$ThreadCount = ([System.Environment]::ProcessorCount),

        [switch]$Service
    )

    # Check log folder
    if (-not (Test-Path -Path $LogFolder -PathType Container))
    {
        New-Item -Path $LogFolder -ItemType Directory | Out-Null
    }

    # Store the module name and version in the shared variables map for use by request threads.
    $SharedVariables.ServerName = $MyInvocation.MyCommand.Module.Name
    $SharedVariables.ServerVersion = $MyInvocation.MyCommand.Module.Version

    # Set the values used by HttpResponse for the 'Server' header
    [HttpResponse]::SetServerIdentifier(($SharedVariables.ServerName + '/' + $SharedVariables.ServerVersion))

    if (-not $SingleThreaded -and $Service)
    {
        Start-MultiThreadedServer -ClassPath $ClassPath -BoundIp $BoundIp -Port $Port -LogFolder $LogFolder -ThreadCount $ThreadCount
    }
    else
    {
        Start-SingleThreadedServer -ClassPath $ClassPath -BoundIp $BoundIp -Port $Port -Service $Service
    }
}