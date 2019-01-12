function New-ListenerThread
{
<#
    .SYNOPSIS
        Creates the listener thread

    .DESCRIPTION
        The listener thread listens for incoming requests then hands them off to a thread for processing.

    .PARAMETER ThreadArguments
        A block of arguments to pass to the listener thread

    .OUTPUTS
        [PowerShell] Configured listener thread.
#>
    param
    (
        [object]$ThreadArguments
    )

    # ScriptBlock that defines the code that the listener thread executes.
    [scriptblock]$listenerTask = {

        param
        (
            [object]$ThreadArguments
        )

        Set-Variable -Name SharedVariables -Option AllScope -Value @{
            CanLogEvents = $ThreadArguments.CanLogEvents
            ServerName = [IO.Path]::GetFileNameWithoutExtension($ThreadArguments.ModulePath)
        }

        # dot source event logging
        $privateDirectory = [IO.Path]::Combine((Split-Path -Parent $ThreadArguments.ModulePath), 'Private')

        ('00-Enums.ps1', 'Write-OperatingSystemLogEntry.ps1', 'Write-SyslogEntry.ps1', 'Write-EventlogEntry.ps1') |
        Foreach-Object {

            . (Get-ChildItem -Recurse -Path $privateDirectory -Filter $_).FullName
        }

        # Class to manage request handling threads.
        class RequestHandlerTask
        {
            # List of currently running jobs
            hidden static [System.Collections.Generic.List[RequestHandlerTask]]$RunningTasks = [System.Collections.Generic.List[RequestHandlerTask]]::new()

            # Thread running this request
            hidden [powershell]$Job

            # Result of the job
            hidden [System.IAsyncResult]$AsyncResult

            RequestHanderTask()
            {
            }

            # Starts a new request handling job
            [void]Start([System.Net.Sockets.TcpClient]$tcpClient, [object]$threadArguments)
            {
                $this.Job = [powershell]::Create()
                $this.Job.RunspacePool = $threadArguments.RequestPool
                $this.Job.
                    AddCommand('Resolve-Request').
                    AddParameter('TcpClient', $tcpClient).
                    AddParameter('CancellationTokenSource', $threadArguments.CancellationTokenSource) |
                    Out-Null

                $this.AsyncResult = $this.Job.BeginInvoke()
                [RequestHandlerTask]::RunningTasks.Add($this)
            }

            # Tests if this jo9b is complete and cleans up if it is
            [bool]IsComplete()
            {
                if ($this.AsyncResult.AsyncWaitHandle.WaitOne(0))
                {
                    # Clean up

                    try
                    {
                        # This throws if there was an unhandled exception in the thread's runspace.
                        $this.Job.EndInvoke($this.AsyncResult)
                    }
                    finally
                    {
                        $this.AsyncResult.AsyncWaitHandle.Close()
                        $this.Job.Dispose()
                    }

                    return $true
                }

                return $false
            }

            # Garbage collect completed jobs
            static [void]GarbageCollect()
            {
                (
                    [RequestHandlerTask]::RunningTasks |
                        Where-Object {
                        $_.IsComplete()
                    }
                ) |
                    ForEach-Object {
                    [RequestHandlerTask]::RunningTasks.Remove($_)
                }
            }
        }

        try
        {
            # Warm threads
            1..$ThreadArguments.ThreadCount |
            ForEach-Object {
                [RequestHandlerTask]::new().Start($null, $threadArguments)
            }

            # Create the listener
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse($ThreadArguments.BoundIp), $ThreadArguments.Port)
            $listener.Start()

            Write-OperatingSystemLogEntry -EventId ([EventId]::ServerStarted) -Message "Server up. Listening on port $($ThreadArguments.Port)"

            $running = $true

            do
            {
                # Wait for a connection
                $clientWaiter = $listener.AcceptTcpClientAsync()

                try
                {
                    $clientWaiter.Wait($threadArguments.CancellationTokenSource.Token)

                    # Connection accepted. Start a job to process it.
                    [RequestHandlerTask]::new().Start($clientWaiter.Result, $threadArguments)

                    # Clean up any jobs that have finished.
                    [RequestHandlerTask]::GarbageCollect()
                }
                catch [OperationCanceledException]
                {
                    # User requested server halt, i.e. TerminateServerException was thrown to cancel the cancellation token.
                    $running = $false
                }
                catch
                {
                    # If anything else caught here, something's badly wrong.
                    # It will usually mean that an unhandled exception propagated out of a request han dling thread and was thrown at EndInvoke()
                    # All exceptions in user code should have already been handled.

                    # Cancel the cancellation token so other threads waiting on it also exit
                    $threadArguments.CancellationTokenSource.Cancel()

                    Write-OperatingSystemLogEntry -EventId ([EventId]::Exception)  -Message "FATAL:`n$($_.Exception.Message)`n$($_.ScriptStacktrace)"

                    $running = $false
                }
            }
            while ($running)
        }
        catch
        {
            # Something went wrong prior to or during opening the socket
            # Cancel the cancellation token so other threads waiting on it also exit
            $threadArguments.CancellationTokenSource.Cancel()
            Write-OperatingSystemLogEntry -EventId ([EventId]::Exception)  -Message "FATAL:`n$($_.Exception.Message)`n$($_.ScriptStacktrace)"
        }
        finally
        {
            if ($listener)
            {
                # Close the listener socket
                $listener.Stop()
            }
        }
    }

    # Create listener thread
    Write-OperatingSystemLogEntry -EventId ([EventId]::InitializationStep) -Message "Creating listener thread."

    $powershell = [powershell]::Create()

    # Add it's code from the scriptblock
    $powershell.AddScript($listenerTask.ToString()).AddArgument($threadArguments) | Out-Null

    # Return the thread
    $powershell
}