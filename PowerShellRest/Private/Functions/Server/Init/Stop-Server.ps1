function Stop-Server
{
<#
    .SYNOPSIS
        Shut down multithreaded server

    .PARAMETER CancellationTokenSource
        The token source object to use for initiating a server shutdown
#>
    param
    (
        [System.Threading.CancellationTokenSource]$CancellationTokenSource
    )

    if ($CancellationTokenSource)
    {
        # Cause blocking threads (listener, logging) to exit, thus ending the process.
        $CancellationTokenSource.Cancel()
    }
    else
    {
        # No cancellation token? Just throw again.
        throw [TerminateServerException]::new()
    }
}