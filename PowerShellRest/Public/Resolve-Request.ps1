function Resolve-Request
{
    <#
    .SYNOPSIS
        Handles an incoming request

    .DESCRIPTION
        Do not call this function directly.

        This function has to be part of the public API as it is called from outside of the module scope
        by the thread that listens for incoming requests.

    .PARAMETER TcpClient
        A connected TcpClent object representing the client making the request.

    .PARAMETER CancellationTokenSource
        The token source object to use for initiating a server shutdown
#>
    param
    (
        [System.Net.Sockets.TcpClient]$TcpClient,
        [System.Threading.CancellationTokenSource]$CancellationTokenSource
    )

    $httpLogEntry = $null
    $errorLogEntry = $null

    try
    {
        # Record start time of request processing
        $startTime = [datetime]::UtcNow

        # Get the client's data stream
        $stream = $TcpClient.GetStream()

        # Create a request object fromn the stream
        $request = [HttpRequest]::new($stream)

        try
        {
            # Read the request stream, i.e. get request and headers
            $request.Read()

            # Process request and get response
            $response = Invoke-Route -Context $request
        }
        catch [HttpException]
        {
            # Under normal circumstances, an [HttpResponse] will always be returned,
            # unless there was an error forming the response, in which case an [HttpException] will be thrown.
            # Any other exception is fatal and handled further down.
            $response = [HttpResponse]::new($_.Exception, $request)
        }

        # Send response to client
        $responseBytes = $response.GetBytes()
        $stream.Write($responseBytes, 0, $responseBytes.Length)

        # Record overall processing time,
        $timeTaken = [int]([datetime]::UtcNow - $startTime).TotalMilliseconds

        # Create an entry for the HTTP log
        $httpLogEntry = [HttpLogEntry]::new($request, $response, $startTime, $timeTaken, $TcpClient.Client)

        # Create an entry for the error log if there was an error
        $errorLogEntry = $(
            if ($response.Status.StatusCode -ge 400)
            {
                [ErrorLogEntry]::new($request, $response, $startTime, $timeTaken, $TcpClient.Client)
            }
            else
            {
                $null
            }
        )
    }
    catch
    {
        # This is a fatal error!
        Write-OperatingSystemLogEntry -EventId ([EventId]::Fatal) -Message "Resolve-Route`n$($_.Exception.Message)`n`n$($_.Exception.GetType().FullName)`n$($_.ScriptStackTrace)"
        Stop-Server -CancellationTokenSource $CancellationTokenSource
        throw
    }
    finally
    {
        # Close client connection.
        $TcpClient.Dispose()
    }

    # Update log files
    if ($null -ne $SharedVariables.LoggingQueue)
    {
        $httpLogString = $httpLogEntry.ToString()
        $errorLogString = $(
            if ($null -ne $errorLogEntry)
            {
                $errorLogEntry.ToString()
            }
            else
            {
                $null
            }
        )

        # Add to logging output queue for processing by logging thread.
        $SharedVariables.LoggingQueue.Add([System.Collections.Generic.KeyValuePair[string, string]]::new($httpLogString, $errorLogString))
    }

    if ($response -is [TerminationResponse])
    {
        # User request to terminate server.
        Stop-Server -CancellationTokenSource $CancellationTokenSource
    }
}