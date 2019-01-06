function New-LoggingThread
{
    param
    (
        [object]$ThreadArguments
    )

    [scriptblock]$loggingTask = {

        param
        (
            [string]$LogFolder,
            [string]$HttpLogHeader,
            [string]$ErrorLogHeader,
            [System.Collections.Concurrent.BlockingCollection[System.Collections.Generic.KeyValuePair[string, string]]]$LogQueue,
            [System.Threading.CancellationToken]$CancellationToken
        )

        if ([string]::IsNullOrEmpty($LogFolder))
        {
            # Nothing to do
            return
        }

        $httpLogInit = $false
        $errorLogInit = $false
        $utf8Encoding = [System.Text.UTF8Encoding]::new($false)

        while ($true)
        {
            try
            {

                # Queue stores KeyValuePair<string,string> objects as a cheap way for storing a pair of strings
                # Key = http log entry
                # Value = error log entry
                $entry = $LogQueue.Take($CancellationToken)

                $dt = [datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')

                $httpLogFile = [System.IO.Path]::Combine($LogFolder, 'HTTP', "u_ex$([dateTime]::UtcNow.ToString('yyMMdd')).log")

                if (-not [System.IO.File]::Exists($httpLogFile))
                {
                    # Init new log
                    [System.IO.File]::WriteAllText($httpLogFile, ($HttpLogHeader -f $dt), $utf8Encoding)
                    $httpLogInit = $true
                }
                elseif (-not $httpLogInit)
                {
                    # Restart on same log file
                    [System.IO.File]::AppendAllText($httpLogFile, ($HttpLogHeader -f $dt), $utf8Encoding)
                    $httpLogInit = $true
                }

                [System.IO.File]::AppendAllText($httpLogFile, $entry.Key, $utf8Encoding)

                if ($null -ne $entry.Value)
                {
                    # We handled an error - either HTTP status >= 400 or an unhandled exception was thrown from user code.

                    $errorLogFile = [System.IO.Path]::Combine($LogFolder, 'Error', "error_$([dateTime]::UtcNow.ToString('yyMMdd')).log")

                    if (-not [System.IO.File]::Exists($errorLogFile))
                    {
                        # Init new log
                        [System.IO.File]::WriteAllText($errorLogFile, ($ErrorLogHeader -f $dt), $utf8Encoding)
                        $errorLogInit = $true
                    }
                    elseif (-not $errorLogInit)
                    {
                        # Restart on same log file
                        [System.IO.File]::AppendAllText($errorLogFile, ($ErrorLogHeader -f $dt), $utf8Encoding)
                        $errorLogInit = $true
                    }

                    [System.IO.File]::AppendAllText($errorLogFile, $entry.Value, $utf8Encoding)
                }
            }
            catch [System.OperationCanceledException]
            {
                # Server terminating
                return
            }
            catch
            {
                Write-EventLog -LogName Application -Source PowerShellRest -EntryType Error -EventId 100 -Message "Logging Thread`n$($_.Exception.Message)`n`n$($_.Exception.GetType().FullName)`n$($_.ScriptStackTrace)"
                # Do nothing for now.
            }
        }
    }

    # Set up log folders
    Initialize-LogFolder -LogFolder $LogFolder

    $moduleInfo = $MyInvocation.MyCommand.Module

    # Create logging thread
    Write-OperatingSystemLogEntry -EventId ([EventId]::InitializationStep) -Message "Creating logging thread."

    $powershell = [powershell]::Create()

    # Add it's code from the scriptblock
    $powershell.AddScript($loggingTask.ToString()).
        AddArgument($ThreadArguments.LogFolder).
        AddArgument([HttpLogEntry]::GetLogHeader($moduleInfo)).
        AddArgument([ErrorLogEntry]::GetLogHeader($moduleInfo)).
        AddArgument($SharedVariables.LoggingQueue).
        AddArgument($ThreadArguments.CancellationTokenSource.Token) | Out-Null

    # Return the thread
    $powershell
}