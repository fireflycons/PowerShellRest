<#
    HTTP Status codes.
    Not an exhaustive list, but those that might reasonably be used in this application
#>
class HttpStatus
{
    <#
        Define an instance of HttpStatus for all supported statuses
    #>
    static [HttpStatus]$Continue = [HttpStatus]::new(100, 'Continue')
    static [HttpStatus]$SwitchingProtocol = [HttpStatus]::new(101, 'Switching Protocol')
    static [HttpStatus]$OK = [HttpStatus]::new(200, 'OK')
    static [HttpStatus]$Created = [HttpStatus]::new(201, 'Created')
    static [HttpStatus]$Accepted = [HttpStatus]::new(202, 'Accepted')
    static [HttpStatus]$NonAuthoritativeInformation = [HttpStatus]::new(203, 'Non-Authoritative Information')
    static [HttpStatus]$NoContent = [HttpStatus]::new(204, 'No Content')
    static [HttpStatus]$ResetContent = [HttpStatus]::new(205, 'Reset Content')
    static [HttpStatus]$PartialContent = [HttpStatus]::new(206, 'Partial Content')
    static [HttpStatus]$MultipleChoice = [HttpStatus]::new(300, 'Multiple Choice')
    static [HttpStatus]$MovedPermanently = [HttpStatus]::new(301, 'Moved Permanently')
    static [HttpStatus]$Found = [HttpStatus]::new(302, 'Found')
    static [HttpStatus]$SeeOther = [HttpStatus]::new(303, 'See Other')
    static [HttpStatus]$NotModified = [HttpStatus]::new(304, 'Not Modified')
    static [HttpStatus]$TemporaryRedirect = [HttpStatus]::new(307, 'Temporary Redirect')
    static [HttpStatus]$PermanentRedirect = [HttpStatus]::new(308, 'Permanent Redirect')
    static [HttpStatus]$BadRequest = [HttpStatus]::new(400, 'Bad Request')
    static [HttpStatus]$Unauthorized = [HttpStatus]::new(401, 'Unauthorized')
    static [HttpStatus]$Forbidden = [HttpStatus]::new(403, 'Forbidden')
    static [HttpStatus]$NotFound = [HttpStatus]::new(404, 'Not Found')
    static [HttpStatus]$MethodNotAllowed = [HttpStatus]::new(405, 'Method Not Allowed')
    static [HttpStatus]$NotAcceptable = [HttpStatus]::new(406, 'Not Acceptable')
    static [HttpStatus]$PreconditionFailed = [HttpStatus]::new(412, 'Precondition Failed')
    static [HttpStatus]$ImATeapot = [HttpStatus]::new(418, "I'm a Teapot")
    static [HttpStatus]$InternalServerError = [HttpStatus]::new(500, 'Internal Server Error')
    static [HttpStatus]$NotImplemented = [HttpStatus]::new(501, 'Not Implemented')
    static [HttpStatus]$BadGateway = [HttpStatus]::new(502, 'Bad Gateway')
    static [HttpStatus]$ServiceUnavailable = [HttpStatus]::new(503, 'Service Unavailable')
    static [HttpStatus]$GatewayTimeout = [HttpStatus]::new(504, 'Gateway Timeout')
    static [HttpStatus]$HttpVersionNotSupported = [HttpStatus]::new(505, 'HTTP Version Not Supported')

    static hidden [Array]$SupportedCodes = @(
        [HttpStatus]::Continue
        [HttpStatus]::SwitchingProtocol
        [HttpStatus]::OK
        [HttpStatus]::Created
        [HttpStatus]::Accepted
        [HttpStatus]::NonAuthoritativeInformation
        [HttpStatus]::NoContent
        [HttpStatus]::ResetContent
        [HttpStatus]::PartialContent
        [HttpStatus]::MultipleChoice
        [HttpStatus]::MovedPermanently
        [HttpStatus]::Found
        [HttpStatus]::SeeOther
        [HttpStatus]::NotModified
        [HttpStatus]::TemporaryRedirect
        [HttpStatus]::PermanentRedirect
        [HttpStatus]::BadRequest
        [HttpStatus]::Unauthorized
        [HttpStatus]::Forbidden
        [HttpStatus]::NotFound
        [HttpStatus]::MethodNotAllowed
        [HttpStatus]::NotAcceptable
        [HttpStatus]::PreconditionFailed
        [HttpStatus]::ImATeapot
        [HttpStatus]::InternalServerError
        [HttpStatus]::NotImplemented
        [HttpStatus]::BadGateway
        [HttpStatus]::ServiceUnavailable
        [HttpStatus]::GatewayTimeout
        [HttpStatus]::HttpVersionNotSupported
    )

    [int]$StatusCode

    [string]$StatusMessage

    <#
        Private constructor. Users can't create new statuses
    #>
    hidden HttpStatus([int]$statusCode, [string]$statusMessage)
    {
        $this.StatusCode = $statusCode
        $this.StatusMessage = $statusMessage
    }

    <#
        Return HttpStatus object for the given code
    #>
    static [HttpStatus]GetStatus([int]$statusCode)
    {
        $stat = [HttpStatus]::SupportedCodes | Where-Object { $_.StatusCode -eq $statusCode }

        if (-not $stat)
        {
            return [HttpStatus]::InternalServerError
        }

        return $stat
    }

    [string]ToString()
    {
        return "$($this.StatusCode) $($this.StatusMessage)"
    }
}