$global:ModuleName = 'PowerShellRest'
$global:ModulePath = (Resolve-Path ([IO.Path]::Combine($PSScriptRoot, '..', 'PowerShellRest', "$ModuleName.psd1"))).Path

Get-Module -Name $ModuleName | Remove-Module

$controllers = [IO.Path]::Combine($PSScriptRoot, 'Controllers', 'MainTests')

Import-Module $global:ModulePath -ArgumentList $controllers

Describe 'Routes' {

    Context 'Routes Load' {

        It 'Context initialization time' {

            # Swallow up the time to initialise  context which skews the time on the first test.
        }

        It 'Should load routes from controller classes' {

            InModuleScope -ModuleName $ModuleName {

                $ControllerTable | Should Not Be $null
            }
        }
    }
}

Describe 'OLTP Controller Classes' {
    # Test controller classes directly

    Context 'CustomerController' {

        It 'Context initialization time' {

            # Swallow up the time to initialise  context which skews the time on the first test.
        }

        It 'Should get customer by Id' {

            InModuleScope -ModuleName $ModuleName {

                $controller = New-Object CustomerController
                $customer = $controller.GetCustomer(1)
                $customer.Id | Should Be 1
            }
        }

        It 'Should list all customers' {

            InModuleScope -ModuleName $ModuleName {

                $controller = New-Object CustomerController
                $customers = $controller.ListCustomer()
                $customers.Count | Should BeGreaterOrEqual 10
            }
        }

        It 'Should return 404 if customer not found' {

            InModuleScope -ModuleName $ModuleName {

                $expectedStatus = [HttpStatus]::NotFound
                $controller = New-Object CustomerController
                $controller.GetCustomer(100) | Should Be $expectedStatus
            }
        }

        It 'Should return new ID when customer is added' {

            InModuleScope -ModuleName $ModuleName {

                $formData = New-Object PSObject -Property @{
                    FirstName = 'Grant'
                    LastName  = 'King'
                }

                $controller = New-Object CustomerController
                $controller.NewCustomer($formData).Id |Should BeGreaterThan 10
            }
        }

        It 'Should return 400 when new customer data cannot be parsed' {

            InModuleScope -ModuleName $ModuleName {

                $formData = New-Object PSObject -Property @{
                    SomeField      = 'Grant'
                    SomeOtherField = 'King'
                }

                $expectedStatus = [HttpStatus]::BadRequest
                $controller = New-Object CustomerController
                $controller.NewCustomer($formData) | Should Be $expectedStatus
            }
        }

        It 'Should delete customer by ID' {

            InModuleScope -ModuleName $ModuleName {

                $controller = New-Object CustomerController
                $expectedDeleteStatus = @([HttpStatus]::Created, [HttpStatus]::Accepted, [HttpStatus]::NoContent)
                $expectedGetStatus = [HttpStatus]::NotFound

                $controller.DeleteCustomer(1) | Should BeIn $expectedDeleteStatus
                $controller.GetCustomer(1) | Should Be $expectedGetStatus
            }
        }
    }
}

Describe 'DevOps controller classes' {

    Context 'ServiceController' {

        $isUnix = -not ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows))

        It 'Context initialization time' {

            # Swallow up the time to initialise  context which skews the time on the first test.
        }

        It 'Should return a list of all services for local computer' {

            if ($isUnix)
            {
                Set-TestInconclusive -Message "Get-Service does not exist on non-Windows platforms"
            }
            else
            {
                InModuleScope -ModuleName $ModuleName {

                    $controller = New-Object ServiceController
                    $services = $controller.GetServices([Environment]::MachineName)
                    $services | Should Not Be $null
                }
            }
        }

        It 'Should get a service by name for local computer' {

            if ($isUnix)
            {
                Set-TestInconclusive -Message "Get-Service does not exist on non-Windows platforms"
            }
            else
            {
                InModuleScope -ModuleName $ModuleName {

                    $controller = New-Object ServiceController
                    $expectedService = $controller.GetServices([Environment]::MachineName) | Select-Object -First 1

                    $actualService = $controller.GetServiceByName([Environment]::MachineName, $expectedService.ServiceName)

                    $actualService.ServiceName | Should Be $expectedService.ServiceName
                }
            }
        }

        It 'Should throw when trying to get a list of all servers for unreachable computer' {

            if ($isUnix)
            {
                Set-TestInconclusive -Message "Get-Service does not exist on non-Windows platforms"
            }
            else
            {
                InModuleScope -ModuleName $ModuleName {

                    $controller = New-Object ServiceController
                    { $controller.GetServices('vadsfgasdgfag') } | Should Throw
                }
            }
        }
    }

    Context 'ProcessController' {

        It 'Context initialization time' {

            # Swallow up the time to initialise  context which skews the time on the first test.
        }

        It 'Should return a list of all processes for local computer' {

            InModuleScope -ModuleName $ModuleName {

                $controller = New-Object ProcessController
                $processes = $controller.GetProcesses([Environment]::MachineName)
                $processes | Should Not Be $null
            }
        }

        It 'Should get a process by id for local computer' {

            InModuleScope -ModuleName $ModuleName {

                $controller = New-Object ProcessController
                $expectedProcess = $controller.GetProcesses([Environment]::MachineName) | Select-Object -First 1

                $actualProcess = $controller.GetProcessById([Environment]::MachineName, $expectedProcess.Id)

                $actualProcess.Id | Should Be $expectedProcess.Id
            }
        }

        It 'Should throw when trying to get a list of all processes for unreachable computer' {

            InModuleScope -ModuleName $ModuleName {

                $controller = New-Object ProcessController
                { $controller.GetProcesses('vadsfgasdgfag') } | Should Throw
            }
        }
    }
}
