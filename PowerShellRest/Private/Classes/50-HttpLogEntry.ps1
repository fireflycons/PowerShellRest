<#
    Base class for log file entires
#>
class ServerLogEntry
{
    [HttpRequest]$Request

    [HttpResponse]$Response

    [DateTime]$RequestTimestamp

    [int]$RequestDuration

    [System.Net.IPEndpoint]$Server

    [System.Net.IPEndpoint]$Client

    ServerLogEntry([HttpRequest]$request, [HttpResponse]$response, [DateTime]$requestTimestamp, [int]$requestDuration, [System.Net.Sockets.Socket]$socket)
    {
        $this.Request = $request
        $this.Response = $response
        $this.RequestTimestamp = $requestTimestamp
        $this.RequestDuration = $requestDuration
        $this.Server = $socket.LocalEndPoint
        $this.Client = $socket.RemoteEndPoint
    }
}

<#
    Formats an entry for the HTTP server log
#>
class HttpLogEntry : ServerLogEntry
{
    HttpLogEntry([HttpRequest]$request, [HttpResponse]$response, [DateTime]$requestTimestamp, [int]$requestDuration, [System.Net.Sockets.Socket]$socket) : base($request, $response, $requestTimestamp, $requestDuration, $socket)
    {
    }

    [string]ToString()
    {
        # Format a log line
        # https://stackify.com/how-to-interpret-iis-logs/

        $query = $(
            if ($null -ne $this.Request.QueryParameters)
            {
                $this.Request.QueryParameters.ToString()
            }
            else
            {
                '-'
            }
        )

        $host = ($this.GetRequestHeaderValue('Host') -split ' ')[0]

        return "{0} {1} {2} {3} {4} {5} {6} {7} {8} {9} {10} {11} {12} {13} {14}`n" -f $this.RequestTimestamp.ToString('yyyy-MM-dd HH:mm:ss'),  # date time 0
            [System.Environment]::MachineName,          # s-computername 1
            $this.Server.Address.IPAddressToString,     # s-ip 2
            $this.Request.RequestMethod,                # cs-method 3
            $this.Request.Path,                         # cs-uri-stem 4
            $query,                                     # cs-uri-query 5
            $this.Server.Port,                          # s-port 6
            $this.Client.Address.IPAddressToString,     # c-ip 7
            ('HTTP/' + $this.Request.ProtocolVersion),  # cs-version 8
            $this.GetRequestHeaderValue('User-Agent'),  # cs(User-Agent) 9
            $this.GetRequestHeaderValue('Referer'),     # cs(Referer) 19
            $host,                                      # cs-host 11
            $this.Response.Status.StatusCode,           # sc-status 12
            $this.Response.BytesSent,                   # sc-bytes 13
            $this.RequestDuration                       # time-taken 14
    }

    static [string]GetLogHeader([PSModuleInfo]$moduleInfo)
    {
        return [System.Text.StringBuilder]::new().
            AppendLine("#Software: $($moduleInfo.Name) $($moduleInfo.Version.ToString())").
            AppendLine('#Version: 1.0').
            AppendLine('#Date: {0}').  # [datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')
            AppendLine('#Fields: date time s-computername s-ip cs-method cs-uri-stem cs-uri-query s-port c-ip cs-version cs(User-Agent) cs(Referer) cs-host sc-status sc-bytes time-taken').
            ToString()
    }

    hidden [string]GetRequestHeaderValue([string]$key)
    {
        if ($this.Request.Headers.ContainsKey($key))
        {
            $value = $this.Request.Headers[$key]

            if ($value -match '\s')
            {
                return "`"$($value)`""
            }

            return $value
        }

        return '-'
    }
}

<#
    Formats an entry for the error log.
#>
class ErrorLogEntry : ServerLogEntry
{
    ErrorLogEntry([HttpRequest]$request, [HttpResponse]$response, [DateTime]$requestTimestamp, [int]$requestDuration, [System.Net.Sockets.Socket]$socket) : base($request, $response, $requestTimestamp, $requestDuration, $socket)
    {
    }

    [string]ToString()
    {
        $query = $(
            if ($null -ne $this.Request.QueryParameters)
            {
                '?' + $this.Request.QueryParameters.ToString()
            }
            else
            {
                [string]::Empty
            }
        )

        $reason = $(
            if ($this.Response.UnderlyingException)
            {
                $this.Response.UnderlyingException.Message.Replace(([System.Environment]::NewLine), ' ')
            }
            else
            {
                $this.Response.Status.StatusMessage
            }
        )

        if ($reason.IndexOf(' ') -gt -1)
        {
            $reason = '"' + $reason.Replace('"', "'") + '"'
        }

        return "{0} {1} {2} {3} {4} {5} {6} {7} {8} {9}`n" -f $this.RequestTimestamp.ToString('yyyy-MM-dd HH:mm:ss'),  # date time 0
            $this.Client.Address.IPAddressToString,     # c-ip 1
            $this.Client.Port,                          # c-port 2
            $this.Server.Address.IPAddressToString,     # s-ip 3
            $this.Server.Port,                          # s-port 4
            ('HTTP/' + $this.Request.ProtocolVersion),  # cs-version 5
            $this.Request.RequestMethod,                         # cs-method 6
            ($this.Request.Path + $query),              # cs-uri 7
            $this.Response.Status.StatusCode,           # sc-status 8
            $reason                                     # s-reason 9
    }

    static [string]GetLogHeader([PSModuleInfo]$moduleInfo)
    {
        return [System.Text.StringBuilder]::new().
            AppendLine("#Software: $($moduleInfo.Name) $($moduleInfo.Version.ToString())").
            AppendLine('#Version: 1.0').
            AppendLine('#Date: {0}').  # [datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')
            AppendLine('#Fields: date time c-ip c-port s-ip s-port cs-version cs-method cs-uri sc-status s-reason').
            ToString()
    }
}