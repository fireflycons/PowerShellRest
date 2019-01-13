$global:ModuleName = 'PowerShellRest'
$global:ModulePath = (Resolve-Path ([IO.Path]::Combine($PSScriptRoot, '..', 'PowerShellRest', "$ModuleName.psd1"))).Path

Get-Module -Name $ModuleName | Remove-Module

$controllers = [IO.Path]::Combine($PSScriptRoot, 'Controllers', 'MainTests')
$module = Import-Module $global:ModulePath -PassThru -ArgumentList $controllers

Describe 'RequestBuilder' {

    Context 'RequestBuilder' {

        It 'Context initialization time' {

            Set-ItResult -Skipped -Because "time to initialise context skews the time on the first test"
        }

        It 'Forms correct request text' {

            . ([IO.Path]::Combine($PSScriptRoot, 'Helpers', 'RequestBuilder.ps1'))

            try
            {
                # Use explicit CRLF so encoding of this script file won't matter
                $expectedText = "GET /process/myserver/2 HTTP/1.1`r`nAccept-Encoding: identity`r`nAccept-Language: en-us`r`nConnection: close`r`nContent-Length: 2`r`nContent-Type: text/plain`r`nHost: my.host.com`r`nUser-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)`r`n`r`n12"

                $rb = [RequestBuilder]::new('GET', '/process/myserver/2').
                AddContent('12')

                $bytes = New-Object byte[] 1024
                $bytesRead = $rb.GetStream().Read($bytes, 0, $bytes.Length)
                $text = [System.Text.Encoding]::UTF8.GetString($bytes, 0, $bytesRead)
                $text | Should Be $expectedText
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

InModuleScope $global:ModuleName {

    . ([IO.Path]::Combine($PSScriptRoot, 'Helpers', 'RequestBuilder.ps1'))

    Describe 'HttpRequest' {

        Context 'Accept Header Parsing' {

            It 'Context initialization time' {

                Set-ItResult -Skipped -Because "time to initialise context skews the time on the first test"
            }

            It 'Should sort accept mime types in correct order' {

                # Get different results sorting items with equal Q-values on win and linux
                # so just assert those with Q-values are ordered correctly
                $expectedOrderReverse = @(
                    '*/*'
                    'application/xml'
                    'text/*'
                )

                $rb = [RequestBuilder]::new('GET', '/simple/1').AddHeader('Accept', '*/*;q=0.8,text/html,text/*,application/xhtml+xml,application/xml;q=0.9')
                $req = [HttpRequest]::new($rb.GetStream())
                $req.Read()
                $arr = ($req.PrioritisedAcceptMimeTypes.Value).Clone()
                [Array]::Reverse($arr)
                $actualOrderReverse = $arr | Select-Object -First 3

                $actualOrderReverse | Should Be $expectedOrderReverse
            }
        }

        Context 'Accept-Encoding header parsing' {

            It 'Context initialization time' {

                Set-ItResult -Skipped -Because "time to initialise context skews the time on the first test"
            }

            It 'Should sort encodings in correct order' {

                $rb = [RequestBuilder]::new('GET', '/simple/1').AddHeader('Accept-Encoding', '*;q=0.5, deflate, gzip;q=1.0')
                $req = [HttpRequest]::new($rb.GetStream())
                $req.Read()
                $actualOrder = $req.PrioritisedAcceptEncodings.Value

                $actualOrder | Select-Object -Last 1 | Should Be '*'
            }
        }

        Context 'Invalid or Unsupported Requests' {

            It 'Should throw for CONNECT method' {

                try
                {
                    $rb = [RequestBuilder]::new('CONNECT', '/process/myserver/2')
                    [HttpRequest]::new($rb.GetStream())
                }
                catch
                {
                    # Can't use Should BeOfType, as deep within pester framework, this type doesn't exist
                    ($_.Exception -is [HttpException]) | Should Be $true
                    $_.Exception.StatusCode | Should Be 501
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

        Context 'GET' {

            It 'Context initialization time' {

                Set-ItResult -Skipped -Because "time to initialise context skews the time on the first test"
            }

            It 'Parses a simple GET' {

                try
                {
                    $rb = [RequestBuilder]::new('GET', '/process/myserver/2')

                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $req.RequestMethod | Should Be 'GET'
                    $req.Path | Should Be '/process/myserver/2'
                    $req.Headers.Count | Should Be 7
                }
                finally
                {
                    if ($rb)
                    {
                        $rb.Dispose()
                    }
                }
            }

            It 'Parses a simple GET with query string' {

                try
                {
                    $rb = [RequestBuilder]::new('GET', '/process/myserver/2?a=1&nullparam&b=dsfdssdf')

                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $req.RequestMethod | Should Be 'GET'
                    $req.Path | Should Be '/process/myserver/2'
                    $req.Headers.Count | Should Be 7
                    $req.QueryParameters.Count | Should Be 3
                    $req.QueryParameters['a'] | Should Be '1'
                    $req.QueryParameters['b'] | Should Be 'dsfdssdf'
                    $req.QueryParameters['nullparam'] | Should Be $null
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

        Context 'POST' {

            It 'Context initialization time' {

                Set-ItResult -Skipped -Because "time to initialise context skews the time on the first test"
            }

            It 'Parses a simple POST' {

                try
                {
                    $rb = [RequestBuilder]::new('POST', '/process/myserver/2').
                    AddHeader('Content-Type', 'application/x-www-form-urlencoded').
                    AddContent('a=1&nullparam&b=dsfdssdf')

                    $req = [HttpRequest]::new($rb.GetStream())
                    $req.Read()

                    $req.RequestMethod | Should Be 'POST'
                    $req.Path | Should Be '/process/myserver/2'
                    $req.Headers.Count | Should Be 7
                    $req.FormParameters.Count | Should Be 3
                    $req.FormParameters['a'] | Should Be '1'
                    $req.FormParameters['b'] | Should Be 'dsfdssdf'
                    $req.FormParameters['nullparam'] | Should Be $null
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