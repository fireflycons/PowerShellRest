<#
    Base class for this module's custom exceptions
#>
class RestException : System.Exception
{
    RestException()
    {
    }

    RestException([string]$message) : base ($message)
    {
    }
}

<#
    Throw this from within a controller method to return an error code to the client
    Generally for 4XX and 5XX statuses.
#>
class HttpException :RestException
{
    [int]$statusCode

    HttpException([int]$statusCode, [string]$message) : base ($message)
    {
        $this.StatusCode = $statusCode
    }

    HttpException([HttpStatus]$status) : base($status.StatusMessage)
    {
        $this.StatusCode = $status.StatusCode
    }
}

<#
    If this exception is thrown by a route controller, the service will terminate
    All other exceptions are handled and returned as HTTP response
#>
class TerminateServerException : RestException
{
    TerminateServerException()
    {
    }
}