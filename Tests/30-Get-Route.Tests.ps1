$global:ModuleName = 'PowerShellRest'
$global:ModulePath = (Resolve-Path ([IO.Path]::Combine($PSScriptRoot, '..', 'PowerShellRest', "$ModuleName.psd1"))).Path

Get-Module -Name $ModuleName | Remove-Module

$controllers = [IO.Path]::Combine($PSScriptRoot, 'Controllers', 'MainTests')
Import-Module $global:ModulePath -ArgumentList $controllers

InModuleScope -Module $ModuleName {

    . ([IO.Path]::Combine($PSScriptRoot, 'Helpers', 'RequestBuilder.ps1'))

    Describe 'Route Matching' {

        Context 'Get-Route' {

            It 'Context initialization time' {

                Set-ItResult -Skipped -Because "time to initialise context skews the time on the first test"
            }

            It '/process/{computerName} should return ProcessController.GetProcesses' {

                $route = "/process/$([Environment]::MachineName)"
                $routeEntry = Get-Route -RequestMethod GET -Path $route
                $routeEntry | Should Not Be $null
                $routeEntry.ToString() | Should Be 'Object ProcessController.GetProcesses(String computerName)'
            }

            It '/process/{computerName}/{name:string} should return ProcessController.GetProcessByName' {

                $route = "/process/$([Environment]::MachineName)/myservice"
                $routeEntry = Get-Route -RequestMethod GET -Path $route
                $routeEntry | Should Not Be $null
                $routeEntry.ToString() | Should Be 'Object ProcessController.GetProcessByName(String computerName, String name)'
            }

            It '/process/{computerName}/{id:int} with valid int value should return ProcessController.GetProcessById' {

                $route = "/process/$([Environment]::MachineName)/1"
                $routeEntry = Get-Route -RequestMethod GET -Path $route
                $routeEntry | Should Not Be $null
                $routeEntry.ToString() | Should Be 'Object ProcessController.GetProcessById(String computerName, Int32 id)'
            }

            It 'Process controller should return ProcessController.GetProcessByName with [long]::MaxValue as ID, because it will only be matched by string argument' {

                $route = "/process/$([Environment]::MachineName)/$([long]::maxValue)"
                $routeEntry = Get-Route -RequestMethod GET -Path $route
                $routeEntry.ToString() | Should Be 'Object ProcessController.GetProcessByName(String computerName, String name)'
            }
        }
    }
}