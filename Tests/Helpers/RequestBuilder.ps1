<#
    Helper class to form a mock HttpRequest stream
#>
class RequestBuilder : System.IDisposable
{
    hidden [System.IO.Stream]$Stream

    hidden [string]$Request

    hidden [hashtable]$Headers = @{}

    hidden [string]$Body = [string]::Empty

    <#
        Construct a mock request backed by a MemoryStream with some default headers
    #>
    RequestBuilder([string]$requestMethod, [string]$path)
    {
        $this.Request = "$($requestMethod.ToUpper()) $path HTTP/1.1"
        $this.Stream = New-Object System.IO.MemoryStream

        $this.
        AddHeader('User-Agent', 'Mozilla/4.0 (compatible; MSIE5.01; Windows NT)').
        AddHeader('Host', 'my.host.com').
        AddHeader('Content-Type', 'text/plain').
        AddHeader('Accept-Language', 'en-us').
        AddHeader('Accept-Encoding', 'identity').
        AddHeader('Connection', 'close') | Out-Null
    }

    <#
        Add a header
    #>
    [RequestBuilder]AddHeader([string]$key, [string]$value)
    {
        if ($this.Headers.ContainsKey($key))
        {
            $this.Headers[$key] = $value
        }
        else
        {
            $this.Headers.Add($key, $value)
        }

        return $this
    }

    <#
        Add some content (request body)
    #>
    [RequestBuilder]AddContent([string]$body)
    {
        $this.Body = $body
        return $this
    }

    <#
        Build and return the request stream
    #>
    [System.IO.Stream]GetStream()
    {
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($this.Body)
        $this.Headers['Content-Length'] = $bodyBytes.Length
        $this.AppendLine($this.Request)

        $this.Headers.Keys |
        Sort-Object |
        ForEach-Object {
            $this.AppendLine("$($_): $($this.Headers[$_])")
        }

        $this.AppendBlankLine()

        if ($bodyBytes.Length -gt 0)
        {
            $this.Stream.Write($bodyBytes, 0, $bodyBytes.Length)
        }

        $this.Stream.Seek(0, [System.IO.SeekOrigin]::Begin)
        return $this.Stream
    }

    hidden [void]WriteString([string]$str)
    {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($str)
        $this.Stream.Write($bytes, 0, $bytes.Length)
    }

    hidden [void]Append([string]$line)
    {
        $this.WriteString("$($line)")
    }

    hidden [void]AppendLine([string]$line)
    {
        $this.WriteString("$($line)`r`n")
    }

    hidden [void]AppendBlankLine()
    {
        $this.WriteString("`r`n")
    }

    [void]Dispose()
    {
        $this.Stream.Dispose()
    }

}
