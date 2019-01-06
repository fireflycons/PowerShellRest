$global:ModuleName = 'PowerShellRest'
$global:ModulePath = (Resolve-Path ([IO.Path]::Combine($PSScriptRoot, '..', 'PowerShellRest', "$ModuleName.psd1"))).Path

Get-Module -Name $ModuleName | Remove-Module

$controllers = [IO.Path]::Combine($PSScriptRoot, 'Controllers', 'MainTests')
Import-Module $global:ModulePath -ArgumentList $controllers

InModuleScope -Module $ModuleName {

    . ([IO.Path]::Combine($PSScriptRoot, 'Helpers', 'RequestBuilder.ps1'))

    Describe 'Invoke-Route' {

        Context 'Unmatched routes' {

            It 'Context initialization time' {

                # Swallow up the time to initialise  context which skews the time on the first test.
            }

            It 'Should return a 404 response for a controller that is not found' {

                try
                {
                    $rb = [RequestBuilder]::new('GET', "/handlerNotPresent/a-string/1")
                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $expectedStatus = [HttpStatus]::NotFound

                    $response = Invoke-Route -Context $req
                    $response.Status | Should Be $expectedStatus
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }

            It 'Should return a 404 response for a route that is not found on a controller that exists' {

                try
                {
                    $rb = [RequestBuilder]::new('GET', "/simple/a-string/another-string")
                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $expectedStatus = [HttpStatus]::NotFound

                    $response = Invoke-Route -Context $req
                    $response.Status | Should Be $expectedStatus
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }
        }

        Context 'Returning default mime type' {

            It 'Context initialization time' {

                # Swallow up the time to initialise  context which skews the time on the first test.
            }

            It 'GET /simple/1 returns 1' {

                try
                {
                    $rb = [RequestBuilder]::new('GET', "/simple/1")
                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $response = Invoke-Route -Context $req
                    $response.Body | Should Be '1'
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }

            It 'GET /simple/a-string/1 returns object containing a-string and 1' {

                try
                {
                    $rb = [RequestBuilder]::new('GET', "/simple/a-string/1")
                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $response = Invoke-Route -Context $req
                    $obj = $response.Body | ConvertFrom-Json

                    $obj.stringVal | Should Be 'a-string'
                    $obj.intVal | Should Be 1
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }

            It 'GET /process/{computerName} should return list of processes as JSON' {

                try
                {
                    $rb = [RequestBuilder]::new('GET', "/process/$([Environment]::MachineName)")

                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    # Count active processes now.
                    $processCount = Get-Process | Measure-Object | Select-Object -ExpandProperty Count

                    $response = Invoke-Route -Context $req
                    $processList = $response.Body | ConvertFrom-Json

                    # Ok, this is a bit woolly, but processes may start or end in the duration of the test execution!
                    $processList.Length | Should BeIn @( (-2..2) | ForEach-Object { $processCount + $_})
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }

            ('gzip', 'deflate') |
            Foreach-Object {

                $algorithm = $_

                It "GET /process/{computerName} should return compressed list of processes as JSON when Accept-Encoding is $algorithm" {

                    try
                    {
                        $rb = [RequestBuilder]::new('GET', "/process/$([Environment]::MachineName)").
                            AddHeader('Accept-Encoding', $algorithm)

                        $req = [HttpRequest]::new($rb.GetStream())
                        $req.Read()

                        # Count active processes now.
                        $processCount = Get-Process | Measure-Object | Select-Object -ExpandProperty Count

                        $response = Invoke-Route -Context $req

                        $compressor = New-Compressor -Algorithm $algorithm
                        $decompressedBody = $compressor.Decompress($response.BodyCompressed)
                        $processList = $decompressedBody | ConvertFrom-Json

                        # Ok, this is a bit woolly, but processes may start or end in the duration of the test execution!
                        $processList.Length | Should BeIn @( (-2..2) | ForEach-Object { $processCount + $_})
                    }
                    finally
                    {
                        if ($rb)
                        {
                            $rb.Dispose()
                        }
                    }
                }
            }

            It 'HEAD /simple/a-string/1 returns non-zero content length, but no content' {

                try
                {
                    $rb = [RequestBuilder]::new('HEAD', "/simple/a-string/1")
                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $response = Invoke-Route -Context $req
                    $response.GetBodyText() | Should be ([string]::Empty)
                    $response.Headers['Content-Length'] | Should BeGreaterThan 0
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }
        }

        Context 'Returning data according to Accept header' {

            It 'Context initialization time' {

                # Swallow up the time to initialise  context which skews the time on the first test.
            }

            It 'GET /simple/a-string/1 returns XML data when accept is text/xml' {

                try
                {
                    $rb = [RequestBuilder]::new('GET', "/simple/a-string/1").AddHeader('Accept', 'text/xml')
                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $response = Invoke-Route -Context $req

                    { [xml]$response.Body } | Should Not Throw
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }

            It 'GET /simple/a-string/1 returns XML data when accept is text/xml,application/json;q=0.9' {

                try
                {
                    $rb = [RequestBuilder]::new('GET', "/simple/a-string/1").AddHeader('Accept', 'text/xml,application/json;q=0.9')
                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $response = Invoke-Route -Context $req

                    { [xml]$response.Body } | Should Not Throw
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }

            It 'GET /simple/a-string/1 returns XML data when accept is application/json;q=0.9,text/xml' {

                try
                {
                    $rb = [RequestBuilder]::new('GET', "/simple/a-string/1").AddHeader('Accept', 'application/json;q=0.9,text/xml')
                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $response = Invoke-Route -Context $req

                    { [xml]$response.Body } | Should Not Throw
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }

            It 'GET /simple/a-string/1 returns plain text data when accept is text/plain,text/*' {

                try
                {
                    $rb = [RequestBuilder]::new('GET', "/simple/a-string/1").AddHeader('Accept', 'text/plain,text/*')
                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $response = Invoke-Route -Context $req

                    { [xml]$response.Body } | Should Throw
                    { $response.Body | ConvertFrom-Json} | Should Throw
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }

            It 'GET /simple/a-string/1 returns plain text data when accept is text/html, text/plain, image/gif, image/jpeg, */*; q=0.01' {

                try
                {
                    $rb = [RequestBuilder]::new('GET', "/simple/a-string/1").AddHeader('Accept', 'text/html, text/plain, image/gif, image/jpeg, */*; q=0.01')
                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $response = Invoke-Route -Context $req

                    { [xml]$response.Body } | Should Throw
                    { $response.Body | ConvertFrom-Json} | Should Throw
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }
        }

        Context 'OPTIONS queries' {

            It 'Context initialization time' {

                # Swallow up the time to initialise  context which skews the time on the first test.
            }

            It 'Returns all server supported request methods for * resource' {

                try
                {
                    $rb = [RequestBuilder]::new('OPTIONS', '*')
                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $response = Invoke-Route -Context $req

                    $response.Headers.Keys | SHould Contain 'Allow'
                    $response.Headers['Allow'] | Should Be ([HttpRequest]::SupportedRequestMethods -join ', ')
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }

            It 'Returns GET, HEAD, OPTIONS for /simple/a-string/1' {

                try
                {
                    $rb = [RequestBuilder]::new('OPTIONS', '/simple/a-string/1')
                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $response = Invoke-Route -Context $req

                    $response.Headers.Keys | SHould Contain 'Allow'
                    $response.Headers['Allow'] | Should Be 'GET, HEAD, OPTIONS'
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }

            It 'Returns DELETE, GET, HEAD, OPTIONS, PUT for /customer/1' {

                try
                {
                    $rb = [RequestBuilder]::new('OPTIONS', '/customer/1')
                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $response = Invoke-Route -Context $req

                    $response.Headers.Keys | SHould Contain 'Allow'
                    $response.Headers['Allow'] | Should Be 'DELETE, GET, HEAD, OPTIONS, PUT'
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }

            It 'Returns 404 for controller not found' {

                try
                {
                    $rb = [RequestBuilder]::new('OPTIONS', '/nonexistantcontroller/1')
                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $expectedStatus = [HttpStatus]::NotFound

                    $response = Invoke-Route -Context $req
                    $response.Status | Should Be $expectedStatus
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }

            It 'Returns 404 for route not found' {

                try
                {
                    $rb = [RequestBuilder]::new('OPTIONS', 'customer/nonexistantroute/1')
                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $expectedStatus = [HttpStatus]::NotFound

                    $response = Invoke-Route -Context $req
                    $response.Status | Should Be $expectedStatus
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }
        }

        Context 'CORS Preflight' {

            It 'Context initialization time' {

                # Swallow up the time to initialise  context which skews the time on the first test.
            }

            It 'Returns DELETE, GET, HEAD, OPTIONS, PUT for /customer/1' {

                try
                {
                    $rb = [RequestBuilder]::new('OPTIONS', '/customer/1').
                        AddHeader('Access-Control-Request-Method', 'PUT').
                        AddHeader('Access-Control-Request-Headers', 'Content-Type')

                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $response = Invoke-Route -Context $req

                    ('Access-Control-Allow-Methods', 'Access-Control-Allow-Headers', 'Access-Control-Allow-Origin', 'Access-Control-Max-Age') |
                    ForEach-Object {
                        $response.Headers.Keys | Should Contain $_
                    }
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }

            It 'Returns forbidden when request method is not available' {

                try
                {
                    $rb = [RequestBuilder]::new('OPTIONS', '/simple/a-string/1').
                        AddHeader('Access-Control-Request-Method', 'POST').
                        AddHeader('Access-Control-Request-Headers', 'Content-Type')

                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $expectedStatus = [HttpStatus]::Forbidden

                    $response = Invoke-Route -Context $req
                    $response.Status | Should Be $expectedStatus
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }
        }

        Context 'Handling Exceptions' {

            It 'Context initialization time' {

                # Swallow up the time to initialise  context which skews the time on the first test.
            }

            It 'Should return a response wtih correct status when HttpException is thrown by a controller' {

                try
                {
                    $expectedStatus = [HttpStatus]::ImATeapot

                    $rb = [RequestBuilder]::new('GET', "/exception/418")
                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $response = Invoke-Route -Context $req
                    $response.Status | Should be $expectedStatus
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }

            It 'Should handle a .NET exception' {

                try
                {
                    $expectedStatus = [HttpStatus]::InternalServerError

                    $rb = [RequestBuilder]::new('GET', "/exception/custom/My%20exception%20message")
                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $response = Invoke-Route -Context $req
                    $response.Status | Should be $expectedStatus
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }

            It 'Should return [TerminationResponse] when controller raises TerminateServerException' {

                try
                {
                    $rb = [RequestBuilder]::new('GET', "/exception/kill")
                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $response = Invoke-Route -Context $req

                    # Classes declared in this module aren't in scope within the bowels of pester so can't use BeOfType
                    ($response -is [TerminationResponse]) | Should Be $true
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }
        }
    }
}