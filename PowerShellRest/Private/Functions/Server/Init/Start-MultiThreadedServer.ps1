function Start-MultiThreadedServer
{
<#
    .SYNOPSIS
        Start the server multi-threaded.

    .DESCRIPTION
        This is provided primarily for debugging, so that the request handling may be steepd into
        Normal operation should be in multithreaded mode.

    .PARAMETER ClassPath
        Path from which to load user controller classes from.

    .PARAMETER BoundIp
        IP address to bind server to. 0.0.0.0 = all local interfaces.

    .PARAMETER Port
        Port to listen on.

    .PARAMETER ThreadCount
        Number of request processing threads to start.

    .PARAMETER LogFolder
        Path to root of logging folder structure.
        Subdirectories 'HTTP' and 'Error' will be created beneath this.
#>
    param
    (
        [string[]]$ClassPath,

        [string]$BoundIp = '0.0.0.0',

        [UInt16]$Port,

        [int]$ThreadCount,

        [string]$LogFolder
    )

    Write-OperatingSystemLogEntry -EventId ([EventId]::ServerStarted) 'Server starting'

    [System.Threading.Mutex]$pesterMutex = $null

    # Look for integration test mutex
    $SharedVariables.IsPester = [System.Threading.Mutex]::TryOpenExisting('PesterWaitServiceStartMutex', [ref]$pesterMutex)

    # Block of arguments that are passed to threads
    $threadArguments = New-Object PSObject -Property @{
        CancellationTokenSource = [System.Threading.CancellationTokenSource]::new()
        BoundIp                 = $BoundIp
        Port                    = $Port
        LogFolder               = Resolve-Path $LogFolder | Select-Object -ExpandProperty Path
        ModulePath              = $MyInvocation.MyCommand.Module.Path
        CanLogEvents            = $SharedVariables.CanLogEvents
        ThreadCount             = $ThreadCount
        RequestPool             = New-RunspacePool -MaxThreads $ThreadCount -ClassPath (
                                    $ClassPath |
                                        ForEach-Object {
                                        Resolve-Path $_ | Select-Object -ExpandProperty Path
                                    }
                                )
    }

    try
    {
        # Create listener and logging threads
        $loggingThread = New-LoggingThread -ThreadArguments $threadArguments
        $listenerThread = New-ListenerThread -ThreadArguments $threadArguments

        Write-OperatingSystemLogEntry -EventId ([EventId]::InitializationStep) 'Initialization complete'

        # Start threads
        $loggingAsync = $loggingThread.BeginInvoke()
        $listenerAsync = $listenerThread.BeginInvoke()

        if ($SharedVariables.IsPester)
        {
            # Release mutex to allow integration tests to proceed.
            $pesterMutex.ReleaseMutex() | Out-Null
        }

        # Wait for threads to end
        $listenerThread.EndInvoke($listenerAsync) | Out-Null
        Assert-ThreadErrors -Thread $listenerThread

        $loggingThread.EndInvoke($loggingAsync) | Out-Null
    }
    catch
    {
        # EndInvoke or Assert-ThreadErrors threw, which means an unhandled exception in the listener thread - indicative of a bug.
        Write-OperatingSystemLogEntry -EventId ([EventId]::Exception) "Error starting multithreaded server: $($_.Exception.Message)"
        throw
    }
    finally
    {
        if ($threadArguments.RequestPool)
        {
            $threadArguments.RequestPool.Dispose()
        }

        Write-OperatingSystemLogEntry -EventId ([EventId]::ServerStopped) 'Server Stopped'
    }
}