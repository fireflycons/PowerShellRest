$moduleName = 'PowerShellRest'
$modulePath = (Resolve-Path ([IO.Path]::Combine($PSScriptRoot, '..', 'PowerShellRest', "$ModuleName.psd1"))).Path

Get-Module -Name $moduleName | Remove-Module
Import-Module $modulePath

$controllerPath = [IO.Path]::Combine($PSScriptRoot, 'Controllers', 'MainTests')
$jobName = "psrest-$(Get-Random)"

function Wait-LogFile
{
    <#
    .SYNOPSIS
        Helper for tests on log files.
        Responses are returned before the log is written so we have to wait for it.

    .PARAMETER Path
        Path to expected log file
#>
    param
    (
        [string]$Path
    )

    for ($i = 0; $i -lt 10; ++$i)
    {
        Start-Sleep -Milliseconds 100

        if ([IO.File]::Exists($Path))
        {
            Start-Sleep -Milliseconds 500
            return
        }
    }

    throw "Log file $Path did not appear after 1000ms"
}

$Global:isPsCore = $Host.Version -ge [Version]'6.0'

Describe 'Integration Tests' -Tag 'Integration' {

    # Log to testdrive so logs are cleaned with each context.
    $logPath = Join-Path $TestDrive Logs

    if (-not (Test-Path -Path $TestDrive -PathType Container))
    {
        throw "Test drive not found"
    }

    $httpLogFile = [System.IO.Path]::Combine($logPath, 'HTTP', "u_ex$([dateTime]::UtcNow.ToString('yyMMdd')).log")
    $errLogFile = [System.IO.Path]::Combine($logPath, 'Error', "error_$([dateTime]::UtcNow.ToString('yyMMdd')).log")

    try
    {
        # Run up the full rest server as a background job
        $startedMutex = [System.Threading.Mutex]::new($false, 'PesterWaitServiceStartMutex')
        $j = Start-Job -Name $jobName -ArgumentList ($modulePath, $controllerPath, $logPath) -ScriptBlock {

            param
            (
                $modulePath,
                $controllerPath,
                $logPath
            )

            # Take ownership of mutex
            $mutex = [System.Threading.Mutex]::OpenExisting('PesterWaitServiceStartMutex')

            if (-not $mutex.WaitOne(5000))
            {
                throw "Could not get ownership of mutex to start the server"
            }

            Import-Module $modulePath

            # Will release mutex once listener thread begins
            Start-RestServer -Port 11000 -Service -ClassPath $controllerPath -LogFolder $logPath
        }

        # Wait for server to be up
        [Console]::WriteLine('    Waiting for server to be ready')

        # Allow process to start and take ownership of the mutex
        Start-Sleep -Seconds 1

        if (-not $startedMutex.WaitOne(30000))
        {
            throw "Did not receive start signal"
        }
        else
        {
            $startedMutex.ReleaseMutex()
        }

        if ($j.State -ne 'Running')
        {
            throw ($j | Receive-Job | Out-String)
        }

        # Run each test in its own context so testdrive cleans out the log files.

        Context 'Single Client - Get one item' {

            It 'Context initialization time' {

                Set-ItResult -Skipped -Because "time to initialise context skews the time on the first test"
            }

            It 'Gets one item' {

                $obj = Invoke-RestMethod http://127.0.0.1:11000/simple/a-string/1

                $obj.stringVal | Should Be 'a-string'
                $obj.intVal | Should Be 1

                Wait-LogFile -Path $httpLogFile
                $httpLogFile | Should FileContentMatch "$([Environment]::MachineName) 127\.0\.0\.1 GET /simple/a-string/1"
            }
        }

        Context 'Single Client - Get 10 items' {

            It 'Context initialization time' {

                Set-ItResult -Skipped -Because "time to initialise context skews the time on the first test"
            }

            It 'Gets 10 items' {

                1..10 |
                    ForEach-Object {
                    $obj = Invoke-RestMethod "http://127.0.0.1:11000/simple/a-string/$_"

                    $obj.stringVal | Should Be 'a-string'
                    $obj.intVal | Should Be $_
                }

                Wait-LogFile -Path $httpLogFile

                # 4 lines of headers, 10 lines of log output.
                Get-Content $httpLogFile | Measure-Object | Select-Object -ExpandProperty Count | Should Be 14
            }
        }

        Context 'Compression' {

            It 'Context initialization time' {

                Set-ItResult -Skipped -Because "time to initialise context skews the time on the first test"
            }

            ('gzip', 'deflate') |
                Foreach-Object {

                $algorithm = $_

                It "GET /process/{computerName} should return compressed list of processes as JSON when Accept-Encoding is $algorithm" {

                    $obj = Invoke-RestMethod "http://127.0.0.1:11000/process/$([Environment]::MachineName)" -Headers @{ 'Accept-Encoding' = $algorithm }
                    $x = 1
                }

            }
        }

        Context 'Multiple Clients - Get 20 items each on 5 clients in parallel' {

            It 'Context initialization time' {

                Set-ItResult -Skipped -Because "time to initialise context skews the time on the first test"
            }

            It 'Handles multiple clients' {

                # 5 jobs, each requesting 20 items = 100 log entries

                $numjobs = 5

                $jobs = 1..$numjobs |
                    ForEach-Object {

                    Start-Job -Name "prrest-test-$_" -ArgumentList $_ -ScriptBlock {

                        param
                        (
                            $jobNum
                        )

                        1..20 |
                            ForEach-Object {

                            Invoke-RestMethod "http://127.0.0.1:11000/simple/job-$jobNum/$_"
                        }
                    }
                }

                $jobs | Wait-Job

                $jobs.State | Sort-Object -Unique | Should Be 'Completed'
                $jobs | Remove-Job

                Wait-LogFile -Path $httpLogFile
                Start-Sleep -seconds 1

                # 4 lines of headers, 100 lines of log output.
                Get-Content $httpLogFile | Measure-Object | Select-Object -ExpandProperty Count | Should Be 104
            }
        }

        Context 'Exception by HTTP Status' {

            It 'Context initialization time' {

                Set-ItResult -Skipped -Because "time to initialise context skews the time on the first test"
            }

            It 'Logs exception by HTTP status code in error log file' {

                try
                {
                    Invoke-RestMethod http://127.0.0.1:11000/exception/418
                    throw "Exception was expected but not thrown"
                }
                catch
                {
                    # Has to be global to be seen within module scope
                    $global:testException = $_.Exception

                    if ($isPsCore)
                    {
                        $testException | Should BeOfType Microsoft.PowerShell.Commands.HttpResponseException
                    }
                    else
                    {
                        $testException | Should BeOfType System.Net.WebException
                    }

                    InModuleScope -ModuleName $moduleName {

                        $expectedStatus = [HttpStatus]::ImATeapot
                        $testException.Response.StatusCode | Should Be $expectedStatus.StatusCode

                        if ($isPsCore)
                        {
                            $testException.Response.ReasonPhrase | Should Be $expectedStatus.StatusMessage
                        }
                        else
                        {
                            $testException.Response.StatusDescription | Should Be $expectedStatus.StatusMessage
                        }
                    }
                }

                Wait-LogFile -Path $errLogFile
                #[Console]::WriteLine((Get-Content $errLogFile | Out-String))
                $errLogFile | Should FileContentMatch "I'm a Teapot"
            }

        }

        Context 'Exception by unhandled .NET exception' {

            It 'Context initialization time' {

                Set-ItResult -Skipped -Because "time to initialise context skews the time on the first test"
            }

            It 'Logs .NET exception in error log file as 500' {

                $expectedMessage = 'My exception message'

                try
                {
                    Invoke-RestMethod "http://127.0.0.1:11000/exception/custom/$([System.Web.HttpUtility]::UrlEncode($expectedMessage))"
                    throw "Exception was expected but not thrown"
                }
                catch
                {
                    # Has to be global to be seen within module scope
                    $global:testException = $_.Exception

                    if ($isPsCore)
                    {
                        $testException | Should BeOfType Microsoft.PowerShell.Commands.HttpResponseException
                    }
                    else
                    {
                        $testException | Should BeOfType System.Net.WebException
                    }

                    InModuleScope -ModuleName $moduleName {

                        $expectedStatus = [HttpStatus]::InternalServerError

                        $testException.Response.StatusCode | Should Be $expectedStatus.StatusCode

                        # Client should not receive the underlying exception message - only that for a 500 error.
                        if ($isPsCore)
                        {
                            $testException.Response.ReasonPhrase | Should Be $expectedStatus.StatusMessage
                        }
                        else
                        {
                            $testException.Response.StatusDescription | Should Be $expectedStatus.StatusMessage
                        }
                    }
                }

                Wait-LogFile -Path $errLogFile
                #[Console]::WriteLine((Get-Content $errLogFile | Out-String))

                # The underlying exception message should be in the log file
                $errLogFile | Should FileContentMatch $expectedMessage
            }
        }

        Context 'Module PreLoad' {

            It 'Context initialization time' {

                # Swallow up the time to initialise context which skews the time on the first test.
            }

            It 'Returns true when a module defined in ModuleDependencies.txt has been preloaded' {

                $result = Invoke-RestMethod http://127.0.0.1:11000/moduledependencies/PowerShellGet

                $result | Should Be 'True'
            }

            It 'Returns false when a module not defined in ModuleDependencies.txt and is not a default module is requested' {

                $result = Invoke-RestMethod http://127.0.0.1:11000/moduledependencies/Pester

                $result | Should Be 'False'
            }
        }

    }

    finally
    {
        $j = Get-Job -Name $jobName -ErrorAction SilentlyContinue

        if ($j)
        {
            [Console]::WriteLine('    Stopping server')

            # Attempt to shut down nicely prior to stopping the job
            try
            {
                Invoke-RestMethod http://127.0.0.1:11000/exception/kill
            }
            catch
            {
            }

            Start-Sleep -Milliseconds 500

            [Console]::WriteLine(($j | Receive-Job | Out-String -Width 300))
            $j | Stop-Job -PassThru | Remove-Job
        }
    }
}
