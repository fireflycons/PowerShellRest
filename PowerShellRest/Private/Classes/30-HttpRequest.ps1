<#
    Object to facilitate sorting qualty-valued objects in a request header
    https://developer.mozilla.org/en-US/docs/Glossary/Quality_values
#>
class QualityValue
{
    # Mime type
    [string]$Value

    # Number of wildcards in the mime type
    [int]$WildcardCount

    # Q-Value
    [double]$QValue

    <#
        Construct from mime type and Q-Value
    #>
    QualityValue([string]$type, [double]$qValue)
    {
        $this.Value = $type
        $this.QValue = $qValue
        $this.WildcardCount = $type.Split('*').Length - 1
    }

    <#
        Construct from mime type only. Q-Value will be 1.0
    #>
    QualityValue([string]$type)
    {
        $this.Value = $type
        $this.QValue = 1
        $this.WildcardCount = $type.Split('*').Length - 1
    }

    <#
        Compare function for sorting as per https://developer.mozilla.org/en-US/docs/Glossary/Quality_values
    #>
    [int]CompareTo([QualityValue]$other)
    {
        if ($null -eq $other)
        {
            return 1
        }

        $cmp = $other.QValue.CompareTo($this.QValue)

        if ($cmp -ne 0)
        {
            # Q-Values are different - stop comparing here
            return $cmp
        }

        # If equal, compare wildcard count. More wildcards = lower precedence
        return $this.WildcardCount.CompareTo($other.WildcardCount)
    }

    [string]ToString()
    {
        return "$($this.Value);q=$($this.QValue)"
    }
}

<#
    Separate IComparer for QualityValue class
    Doesn't work when attempting to inherit QualityValue from IComparable<T>
#>
class QualityValueComparer : System.Collections.Generic.IComparer[QualityValue]
{
    static [QualityValueComparer]$Comparer = [QualityValueComparer]::new()

    QualityValueComparer()
    {
    }

    [int]Compare([QualityValue]$x, [QualityValue]$y)
    {
        if ($null -eq $x -and $null -eq $y)
        {
            return 0
        }

        if ($null -eq $x)
        {
            return 1
        }

        if ($null -eq $y)
        {
            return -1
        }

        return $x.CompareTo($y)
    }
}

<#
    Class to read and process an incoming HTTP request stream.
#>
class HttpRequest
{
    # HTTP request stream
    hidden [System.IO.Stream]$HttpStream

    static [string[]]$SupportedRequestMethods = @('HEAD', 'GET', 'POST', 'PUT', 'DELETE', 'OPTIONS')

    # Number of bytes read so far from stream
    [int]$BytesRead = 0

    # Request verb (GET etc.)
    [string]$RequestMethod

    # Request path (without any query string)
    [string]$Path

    # HTTP protocol version (1.0, 1.1 etc)
    [Version]$ProtocolVersion

    # Parsed query parameters (if any)
    [System.Collections.Specialized.NameValueCollection]$QueryParameters = $null

    # Parsed form parameters (if any)
    [System.Collections.Specialized.NameValueCollection]$FormParameters = $null

    # Parsed headers
    [hashtable]$Headers = @{}

    # List of Accept header mime types sorted by priority.
    [System.Collections.Generic.List[QualityValue]]$PrioritisedAcceptMimeTypes = [System.Collections.Generic.List[QualityValue]]::new()

    # List of Accept-Encoding types sorted by priority
    [System.Collections.Generic.List[QualityValue]]$PrioritisedAcceptEncodings = [System.Collections.Generic.List[QualityValue]]::new()

    <#
        Construct request object
    #>
    HttpRequest([System.IO.Stream]$httpStream)
    {
        $this.HttpStream = $httpStream
    }

    <#
        Read the incoming request stream and parse it
    #>
    [void]Read()
    {
        $sr = $null

        try
        {
            $sr = [System.IO.StreamReader]::new($this.HttpStream, [System.Text.Encoding]::UTF8, $true, 1024, $true)

            $requestLine = $sr.ReadLine()
            $this.BytesRead += $requestLine.Length + 2

            # Parse the request line, e.g. GET /some/resource?param=value HTTP/1.0
            if ($requestLine -match '^(?<verb>([A-Z]+))\s+(?<path>.*?)\s+HTTP/(?<protocol>\d\.\d)')
            {
                if ([HttpRequest]::SupportedRequestMethods -inotcontains $Matches.verb)
                {
                    throw [HttpException]::new(501, "$($Matches.verb) not supported")
                }

                $this.RequestMethod = $Matches.verb
                $this.ProtocolVersion = [Version]::Parse($Matches.protocol)
                ($this.Path, $query) = $Matches.path.Split('?')

                if ($null -ne $query)
                {
                    $this.QueryParameters = [System.Web.HttpUtility]::ParseQueryString($query)
                }
            }
            else
            {
                throw [HttpException]::new(400, "Invalid request")
            }

            # Read headers
            $this.Headers = @{}
            $line = $sr.ReadLine()
            $this.BytesRead += $line.Length + 2

            while (-not ([string]::IsNullOrWhiteSpace($line)))
            {
                ($key, $value) = $line -split ':'
                $this.Headers.Add($key, $value.Trim())
                $line = $sr.ReadLine()
                $this.BytesRead += $line.Length + 2
            }

            # Validate POST content-type.
            # TODO: Support multipart encoding
            if ($this.RequestMethod -ieq 'POST' -and $this.Headers.ContainsKey('Content-Type'))
            {
                switch (($this.Headers['Content-Type'] -split ';')[0])
                {
                    'application/x-www-form-urlencoded'
                    {
                        # Should read content by content length
                        $this.FormParameters = [System.Web.HttpUtility]::ParseQueryString($sr.ReadLine())
                    }

                    default
                    {
                        throw [HttpException]::new(400, "Content type $_ not supported")
                    }
                }
            }
        }
        finally
        {
            if ($sr)
            {
                $sr.Dispose()
            }
        }

        $this.ParseAcceptHeaders()
    }

    <#
        Test for CORS request by presense of Access-Control-Request headers
    #>
    [bool]IsCorsRequest()
    {
        return $null -ne ($this.Headers.Keys | Where-Object { $_ -ilike 'Access-Control-Request*' } | Select-Object -First 1)
    }

    <#
        Reform the request header as a string, primarily for dfebugging.
    #>
    [string]RequestHeader()
    {
        $sb = [System.Text.StringBuilder]::new()

        $pathAndQuery = $this.Path + $(
            if ($null -eq $this.QueryParameters)
            {
                [string]::Empty
            }
            else {
                '?' + $this.QueryParameters.ToString()
            }
        )

        $sb.AppendLine("$($this.RequestMethod) $($pathAndQuery) HTTP/$($this.ProtocolVersion.ToString())") | Out-Null
        $this.Headers.Keys |
        ForEach-Object {
            $sb.AppendLine("$($_): $($this.Headers[$_])") | Out-Null
        }

        return $sb.ToString()
    }

    <#
        Parse Accept and Accept-Encoding headers
    #>
    hidden [void]ParseAcceptHeaders()
    {
        if ($this.Headers.ContainsKey('Accept'))
        {
            $this.ParseQValueHeader('Accept', $this.PrioritisedAcceptMimeTypes)
        }
        else
        {
            # Assume the client will accept anything
            $this.PrioritisedAcceptMimeTypes.Add([QualityValue]::new('*/*'))
        }

        if ($this.Headers.ContainsKey('Accept-Encoding'))
        {
            $this.ParseQValueHeader('Accept-Encoding', $this.PrioritisedAcceptEncodings)
        }
        else
        {
            # If no Accept-Encoding, then assume client accepts 'identity'
            $this.PrioritisedAcceptEncodings.Add([QualityValue]::new('identity'))
        }
    }

    <#
        Parse Q-Value header into a sorted array
        https://developer.mozilla.org/en-US/docs/Glossary/Quality_values
    #>
    hidden [void]ParseQValueHeader([string]$headerName, [System.Collections.Generic.List[QualityValue]]$resultList)
    {
        $this.Headers[$headerName] -split ',' |
            ForEach-Object {
            $acc = $_.Trim()

            if ($acc -match '^(?<value>[\w\d\+\*/]+)(\s*\;\s*q=(?<qvalue>\d\.\d+))?')
            {
                if ($Matches.ContainsKey('qvalue'))
                {
                    $resultList.Add([QualityValue]::new($matches.value, [double]::Parse($matches.qvalue)))
                }
                else
                {
                    $resultList.Add([QualityValue]::new($matches.value))
                }
            }
        }

        $resultList.Sort([QualityValueComparer]::Comparer)
    }
}
