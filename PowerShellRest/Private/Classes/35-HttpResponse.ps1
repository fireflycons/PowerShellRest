<#
    Handles formation of response to client
#>
class HttpResponse
{
    # Culture for formatting response timestamps
    static hidden [System.Globalization.CultureInfo]$CultureEnUS = [System.Globalization.CultureInfo]::CreateSpecificCulture("en-US")

    # Default server identifier. Set to specific value during init.
    static hidden [string]$ServerIdentifier = 'PowerShellRest/0.0'

    # Status code for response
    [HttpStatus]$Status

    # Resonse body text
    [string]$Body

    # Encoded body text
    [byte[]]$BodyCompressed = $null

    # Default content type
    [string]$ContentType = 'text/plain'

    # Response headers
    [hashtable]$Headers = @{}

    # Number of bytes sent to client
    [int]$BytesSent = 0

    # If a .NET exception (not one defined in this module) was caught, it is stored here for reporting to the error log file
    [Exception]$UnderlyingException = $null

    # Original request verb (GET etc.)
    [HttpRequest]$Request

    HttpResponse([HttpStatus]$status, [HttpRequest]$request)
    {
        $this.Request = $request
        $this.Status = $status
        $this.AddDefaultHeaders()
    }

    HttpResponse([HttpStatus]$status, [string]$body, [string]$contentType, [HttpRequest]$request)
    {
        $this.Request = $request
        $this.Status = $status
        $this.Body = $body

        if (-not [string]::IsNullOrEmpty($contentType))
        {
            $this.ContentType = $contentType
        }

        $this.AddDefaultHeaders()
        $this.ApplyEncoding()
    }

    HttpResponse([HttpException]$exception, [HttpRequest]$request)
    {
        $this.Request = $request

        $stat = [HttpStatus]::GetStatus($exception.StatusCode)

        if ($null -eq $stat)
        {
            $this.Status = [HttpStatus]::InternalServerError
            $this.Body = "Unsupported status code $($exception.StatusCode)"
        }
        else
        {
            $this.Status = $stat
            $this.Body = $exception.Message
        }

        $this.AddDefaultHeaders()
    }

    HttpResponse([HttpStatus]$status, [Exception]$underlyingException, [HttpRequest]$request)
    {
        $this.Request = $request
        $this.Status = $status
        $this.Body = $status.StatusMessage
        $this.UnderlyingException = $underlyingException
        $this.ContentType = 'text/plain'

        $this.AddDefaultHeaders()
    }

    <#
        Called during initialisation to set the 'Server' header for responses
    #>
    static [void]SetServerIdentifier([string]$ServerIdentifier)
    {
        [HttpResponse]::ServerIdentifier = $ServerIdentifier
    }

    <#
        Gets the body text according to the request verb
        i.e. HEAD = don't return content
    #>
    [string]GetBodyText()
    {
        if (('OPTIONS', 'HEAD') -icontains $this.Request.RequestMethod -or [string]::IsNullOrEmpty($this.Body))
        {
            return [string]::Empty
        }

        return $this.Body
    }

    <#
        Add or replace a response header
    #>
    [HttpResponse]AddHeader([string]$name, [string]$value)
    {
        $this.Headers[$name] = $value
        return $this
    }

    [string]ToString()
    {
        return $this.GetHeaderString() + $this.GetBodyText()
    }

    <#
        Format the header block (up to where the content begins) as a single string
    #>
    [string]GetHeaderString()
    {
        $sb = New-Object System.Text.StringBuilder

        $stat = $this.Status.StatusCode.ToString() + ' ' + $this.Status.StatusMessage
        $sb.Append("HTTP/1.1 $($stat)`r`n") | Out-Null

        $this.Headers.Keys |
        ForEach-Object {
            $val = $this.Headers[$_]
            $sb.Append("$($_): $val`r`n") | Out-Null
        }

        $sb.Append("`r`n") | Out-Null

        return $sb.ToString()
    }

    <#
        Get the response as a byte array for transmission to client
    #>
    [byte[]]GetBytes()
    {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($this.GetHeaderString()) +
        $(
            if ($null -ne $this.BodyCompressed)
            {
                #Write-EventLog -LogName Application -Source PowerShellRest -EventId 0x0f -EntryType Information -Message "Returning compressed response"
                $this.BodyCompressed
            }
            else
            {
                #Write-EventLog -LogName Application -Source PowerShellRest -EventId 0x0f -EntryType Information -Message "Returning uncompressed response"
                [System.Text.Encoding]::UTF8.GetBytes($this.GetBodyText())
            }
        )

        $this.BytesSent = $bytes.Length
        return $bytes
    }

    <#
        Apply encoding according to Accept-Encoding request header
    #>
    hidden [void]ApplyEncoding()
    {
        $bodyText = $this.GetBodyText()

        if ([string]::IsNullOrEmpty($bodyText))
        {
            return
        }

        foreach ($encoding in $this.Request.PrioritisedAcceptEncodings)
        {
            $algorithm = $encoding.Value

            if (('*', 'identity') -icontains $algorithm)
            {
                return
            }

            $compressor = New-Compressor -Algorithm $algorithm

            if ($compressor)
            {
                $this.BodyCompressed = $compressor.Compress($bodyText)
                $this.AddHeader('Content-Encoding', $algorithm.ToLowerInvariant())
                $this.AddHeader('Content-Length', $this.BodyCompressed.Length.ToString())
                return
            }
        }

        # If we get here, then specific Accept-Encoding was supplied without 'identity' or '*' as an option
        throw [HttpException]::new([HttpStatus]::NotAcceptable)
    }

    <#
        Set the default headers on the response
    #>
    hidden [void]AddDefaultHeaders()
    {
        $dateAsString = [DateTime]::UtcNow.ToString('r', [HttpResponse]::CultureEnUS)
        $contentLength = $(
            if ([string]::IsNullOrEmpty($this.Body))
            {
                0
            }
            else
            {
                [System.Text.Encoding]::UTF8.GetBytes($this.Body).Length
            }
        )

        $this.Headers.Add('Content-Length', $contentLength.ToString())
        $this.Headers.Add('Server', [HttpResponse]::ServerIdentifier)
        $this.Headers.Add('Date', $dateAsString)
        $this.Headers.Add('Last-Modified', $dateAsString)
        $this.Headers.Add('Content-Type', $this.ContentType)
        $this.Headers.Add('Connection', 'Closed')
    }
}

<#
    Subclass of HttpResponse to indicate the server wants to terminate
#>
class TerminationResponse : HttpResponse
{
    TerminationResponse([HttpRequest]$request) : base([HttpStatus]::ServiceUnavailable, "The server is shutting down", $request)
    {
    }
}