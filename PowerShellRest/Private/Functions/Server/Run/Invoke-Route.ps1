function Invoke-Route
{
<#
    .SYNOPSIS
        Parse and invoke a route

    .DESCRIPTION
        Given an incoming HTTP request, parse it, select a route and invoke it then return an HTTP response to send back to the client
        If the route can't be matched, return a 404 response.
        If an unrecognised exception is caught, return a 500 response
        If the special TerminateServerException is caught, rethrow to terminate the service cleanly.

    .PARAMETER Context
        The incomning HTTP request

    .OUTPUTS
        [HttpResponse] - to return to the client.
#>
    param
    (
        [HttpRequest]$Context
    )

    #Write-OperatingSystemLogEntry -EventId ([EventId]::DebugEvent) -Message $Context.RequestHeader()

    if ($Context.RequestMethod -ieq 'OPTIONS')
    {
        # Handle OPTIONS request directly

        if ($Context.Path -eq '*')
        {
            # OPTIONS request at server level
            return [HttpResponse]::new([HttpStatus]::OK, $Context).
                AddHeader('Allow', ([HttpRequest]::SupportedRequestMethods -join ', ')).
                AddHeader('Cache-Control', 'max-age=604800')
        }

        # identify request methods for resource
        $allowedMethods = Get-AllowedRequestMethods -Path $Context.Path

        if ($null -eq $allowedMethods)
        {
            return [HttpResponse]::new([HttpStatus]::NotFound, $Context)
        }

        $response = [HttpResponse]::new([HttpStatus]::OK, $Context)

        if ($Context.IsCorsRequest())
        {
            # CORS preflight - allow anyone.
            # One day, implement CORS as an attribute on routes and negotiate it properly.

            # Check allowed methods contains the requested method
            if ($allowedMethods -inotcontains $Context.Headers['Access-Control-Request-Method'])
            {
                return [HttpResponse]::new([HttpStatus]::Forbidden, $Context)
            }

            if ($Context.Headers.ContainsKey('Access-Control-Request-Headers'))
            {
                $response.AddHeader('Access-Control-Allow-Headers', $Context.Headers['Access-Control-Request-Headers']) | Out-Null
            }

            return $response.
                AddHeader('Access-Control-Allow-Origin', '*').
                AddHeader('Access-Control-Allow-Methods', ($allowedMethods -join ', ')).
                AddHeader('Access-Control-Max-Age', '86400').
                AddHeader('Vary', 'Accept-Encoding, Origin')
        }

        return $response.
            AddHeader('Allow', ($allowedMethods -join ', ')).
            AddHeader('Cache-Control', 'max-age=604800')

    }

    # Find route
    $route = Get-Route -RequestMethod $Context.RequestMethod -Path $Context.Path

    if (-not $route)
    {
        # No match - 404
        return [HttpResponse]::new([HttpStatus]::NotFound, $Context)
    }

    try
    {
        # Invoke the route
        $result = $route.Invoke($Context.Path)
    }
    catch
    {
        $addtionalStackTrace = $(
            if ($_.Exception.InnerException -is [System.Management.Automation.RuntimeException])
            {
                $_.Exception.InnerException.Stacktrace
            }
            else
            {
                [string]::Empty
            }
        )
        # Look for an application defined exception
        $ex = Get-UnderlyingException -Exception $_.Exception

        # We can't get the full stack trace beneath the invocation error,
        # but we can get the method that was invoked (see RouteEnrty.Invoke)
        $invokedMethod = $(
            try {
                "`nInvoked method: " + $_.Exception.InvokedMethodSignature
            }
            catch {
                [string]::Empty
            }
        )

        # Log the exception
        Write-OperatingSystemLogEntry -EventId ([EventId]::RouteHandlingException) -Message "$($ex.GetType().FullName): $($ex.Message)$($invokedMethod)`n$($addtionalStackTrace + $_.ScriptStackTrace)"

        if ($ex -is [RestException])
        {
            # Found one - act accordingly
            if ($ex -is [HttpException])
            {
                return [HttpResponse]::new($ex, $Context)
            }

            if ($ex -is [TerminateServerException])
            {
                return [TerminationResponse]::new($Context)
            }
        }

        # Didn't find one - 500
        return [HttpResponse]::new([HttpStatus]::InternalServerError, $ex, $Context)
    }

    # Based on what was returned by the selected route method, form approptiate response
    if ($result -is [HttpStatus])
    {
        return [HttpResponse]::new($result, $Context)
    }

    if ($result -is [string])
    {
        return [HttpResponse]::new([HttpStatus]::OK, $result, 'text/plain', $Context)
    }

    if ($result -is [HttpResponse])
    {
        return $result
    }

    if ($result -is [ValueType] -and $result.GetType().IsPrimitive)
    {
        # Primitives, e.g. numerics, bools etc.
        return [HttpResponse]::new([HttpStatus]::OK, $result.ToString(), 'text/plain', $Context)
    }

    # Else, some kind of object or a struct like DateTime
    #
    # BEWARE: Long lists of complex objects e.g. the result of Get-Process
    #         take many seconds in the ConvertTo-xxx cmdlets!
    #         In cases such as this, you may want to consider returning
    #         reduced information in list-all methods via Select-Object or similar (see tests)
    foreach($mimeType in $Context.PrioritisedAcceptMimeTypes.Value)
    {
        if ('application/json' -like $mimeType)
        {
            return [HttpResponse]::new([HttpStatus]::OK, ($result | ConvertTo-Json -Depth 50 -Compress), 'application/json', $Context)
        }

        if ('text/xml' -like $mimeType)
        {
            return [HttpResponse]::new([HttpStatus]::OK, ($result | ConvertTo-Xml -Depth 50 -As String), 'text/xml', $Context)
        }

        if ('text/plain' -like $mimeType)
        {
            if ($result -is [PSObject])
            {
                return [HttpResponse]::new([HttpStatus]::OK, ($result | Out-String -Width 5000), 'text/plain', $Context)
            }
            else
            {
                # If the object here is your own PowerShell class, you should implement ToString()
                return [HttpResponse]::new([HttpStatus]::OK, $result.ToString(), 'text/plain', $Context)
            }
        }
    }

    # If we get here, no suitable accept mime type was found
    return [HttpResponse]::new([HttpStatus]::PreconditionFailed, 'Cannot provide content as requested by Accept header', 'text/plain', $Context)
}