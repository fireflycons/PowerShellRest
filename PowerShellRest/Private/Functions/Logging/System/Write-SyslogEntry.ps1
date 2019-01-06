function Write-SyslogEntry
{
    <#
    .SYNOPSIS
        Sends a SYSLOG message to a server running the SYSLOG daemon

    .DESCRIPTION
        Sends a message to a SYSLOG server as defined in RFC 5424. A SYSLOG message contains not only raw message text,
        but also a severity level and application/system within the host that has generated the message.

    .PARAMETER Server
        Destination SYSLOG server that message is to be sent to (default localhost)

    .PARAMETER EventId
        Event ID for log

    .PARAMETER Message
        Message to log

    .PARAMETER Port
        SYSLOG UDP port to send message to (default 514)
#>
    param
    (
        [Parameter(mandatory = $true, Position = 0)]
        [String] $Message,

        [Parameter(mandatory = $true)]
        [EventId] $EventId,

        [String] $Server = 'localhost',

        [int] $Port = 514
    )

    try
    {
        # Evaluate the facility and severity based on the enum types
        $evId = [int]$EventId

        $facility = 3 # daemon
        $severity = $(
            if ($evId -ge 0x20)
            {
                3 # Error
            }
            elseif ($evId -ge 0x10)
            {
                4 # Warning
            }
            else
            {
                6 # Information
            }
        )

        # Calculate the priority
        $priority = ($facility * 8) + $severity

        # Assemble the full syslog formatted message
        $formattedMessage = "<{0}>{1} {2} {3}" -f $priority, [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'), [Environment]::MachineName, "(PID: $($PID), RS: $((Get-Host).RunSpace.Id)) $($Message)"

        # If the message is too long, shorten it
        if ($formattedMessage.Length -gt 1024)
        {
            $formattedMessage = $formattedMessage.SubString(0, 1024)
        }

        # Convert to byte array for transmission
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($formattedMessage)

        # Connect to syslog daemon
        $udpClient = [System.Net.Sockets.UdpClient]::new()
        $udpClient.Connect($Server, $Port)

        # Send the Message
        $udpClient.Send($bytes, $bytes.Length) | Out-Null
    }
    finally
    {

        if ($udpClient)
        {
            $udpClient.Dispose()
        }
    }

}