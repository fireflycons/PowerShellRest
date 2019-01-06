function Start-SingleThreadedServer
{
<#
    .SYNOPSIS
        Start the server single-threaded, i.e. on the main thread

    .DESCRIPTION
        This is provided primarily for debugging, so that the request handling may be steepd into
        Normal operation should be in multithreaded mode.

    .PARAMETER ClassPath
        Path from which to load user controller classes from

    .PARAMETER BoundIp
        IP address to bind server to. 0.0.0.0 = all local interfaces

    .PARAMETER Port
        Port to listen on

    .PARAMETER Service
        If not set, the server will terminate after processing the first request.
#>
    param
    (
        [string[]]$ClassPath,

        [string]$BoundIp = '0.0.0.0',

        [UInt16]$Port,

        [bool]$Service
    )

    $listener = $null

    if ($null -eq $script:ControllerTable)
    {
        $pluginPaths = $ClassPath |
            ForEach-Object {
            (Resolve-Path $_).Path
        }

        # Import module dependencies
        Get-ModuleDependencies -ClassPath $pluginPaths |
        Foreach-Object {

            Import-Module $_
        }

        # Load user classes now
        $pluginPaths |
            Where-Object {
            -not [string]::IsNullOrEmpty($_) -and (Test-Path -Path $_ -PathType Container)
        } |
            ForEach-Object {

            Get-ChildItem -Path $_ -Recurse -File -Filter *.ps1 -ErrorAction SilentlyContinue
        } |
            ForEach-Object {

            try
            {
                . $_.Fullname
            }
            catch
            {
                Write-Error -Message "Failed to import function $($import.fullname): $_"
            }
        }

        $script:ControllerTable = New-ControllerTable
    }

    # If there's no routes defined, exit
    if (@($script:ControllerTable).Count -eq 0)
    {
        throw 'No routes defined.'
    }

    try
    {
        # Create the listener
        $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Parse($BoundIp), $Port)
        $listener.Start()
        Write-Host "Server started. Listening on port $Port"

        $running = $true

        do
        {
            # Wait for a connection
            $client = $listener.AcceptTcpClient()

            try
            {
                Resolve-Request -TcpClient $client
            }
            catch
            {
                Write-Host $_.Exception.Message
                Write-Host $_.ScriptStackTrace
                # Should only get here on TerminateServerException
                $running = $false
            }
        }
        while ($Service -and $running)
    }
    finally
    {
        if ($listener)
        {
            # Close the listener socket
            Write-Host "Closing listener"
            $listener.Stop()
        }
    }
}