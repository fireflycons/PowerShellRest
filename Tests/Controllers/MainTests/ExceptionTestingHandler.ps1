[Controller('/exception')]
class ExceptionTestingController
{
    [Route('/{statusCode:int}')]
    [object]ThrowHttpException([int]$statusCode)
    {
        throw [HttpException]::new([HttpStatus]::GetStatus($statusCode))
    }

    [Route('/kill')]
    [object]Kill()
    {
        throw [TerminateServerException]::new()
    }

    [Route('/custom/{message}')]
    [object]ThrowWithMessage([string]$message)
    {
        throw [ApplicationException]::new($message)
        return $null
    }
}