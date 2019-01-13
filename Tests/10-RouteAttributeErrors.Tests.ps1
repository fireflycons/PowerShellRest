$ErrorActionPreference = 'Stop'

$global:ModuleName = 'PowerShellRest'
$global:ModulePath = (Resolve-Path ([IO.Path]::Combine($PSScriptRoot, '..', 'PowerShellRest', "$ModuleName.psd1"))).Path

Get-Module -Name $ModuleName | Remove-Module

function Invoke-TestModuleLoadAsJob
{
<#
    .SYNOPSIS
        Helper function to wrap a test in a PowerShell job to isolate assembly loads

    .DESCRIPTION
        These tests must run as jobs because once a PowerShell class is defined,
        it remains in an in-memory assembly till the session terminates.

    .PARAMETER ClassPath
        Path to load test class(es) from

    .OUTPUTS
        [string] Exception message we are testing for
#>
    param
    (
        [string]$ClassPath
    )

    $j = Start-Job -ArgumentList ((Resolve-Path $global:ModulePath).Path, $ClassPath) -ScriptBlock {
        param
        (
            $module,
            $classPath
        )

        Set-Item Env:\Pester -Value Pester

        if ($null -eq $classPath)
        {
            Import-Module $module
        }
        else
        {
            Import-Module $module -ArgumentList $classPath
        }

        Remove-Item Env:\Pester

    } | Wait-Job

    try
    {
        $j | Receive-Job | Out-Null
        $null
    }
    catch
    {
        $_.Exception.Message
    }
}

Describe 'Route Attribute Errors' {

    Context 'Same route defined in more than one place' {

        It 'Context initialization time' {

            Set-ItResult -Skipped -Because "time to initialise context skews the time on the first test"
        }

        It 'Should throw when two methods in same class declare same route' {

            $expectedErrorMessage = '(Object Controller1.Method1(Int32 val), Object Controller1.Method2(Int32 val)) define the same route: GET /Controller1/x/{val}'

            Invoke-TestModuleLoadAsJob -ClassPath ([IO.Path]::Combine($PSScriptRoot, 'Controllers', 'StartupErrors', 'OneClassSameRoute')) | Should Be $expectedErrorMessage
        }

        It 'Should throw when methods in separate classes declare same route' {

            $expectedErrorMessage = '(Controller1 [/throwme], Controller2 [/throwme]) define the same base route.'

            Invoke-TestModuleLoadAsJob -ClassPath ([IO.Path]::Combine($PSScriptRoot, 'Controllers', 'StartupErrors', 'TwoClassesSameRoute')) | Should Be $expectedErrorMessage
        }
    }

    Context 'Multiple definitions of same attribute type on one method' {

        It 'Context initialization time' {

            Set-ItResult -Skipped -Because "time to initialise context skews the time on the first test"
        }

        It 'Should throw when a method defines more than one route' {

            $expectedErrorMessage = 'Object Controller1.method1(Int32 val) - Multiple routes not allowed.'

            Invoke-TestModuleLoadAsJob -ClassPath ([IO.Path]::Combine($PSScriptRoot, 'Controllers', 'StartupErrors', 'MultipleRouteAttributes')) | Should Be $expectedErrorMessage
        }

        It 'Should throw when a method defines more than one verb' {

            $expectedErrorMessage = 'Object Controller1.method1(Int32 val) - Multiple HTTP Verbs not allowed.'

            Invoke-TestModuleLoadAsJob -ClassPath ([IO.Path]::Combine($PSScriptRoot, 'Controllers', 'StartupErrors', 'MultipleVerbAttributes')) | Should Be $expectedErrorMessage
        }
    }

    Context 'Multiple controller declarations on same class' {

        It 'Context initialization time' {

            Set-ItResult -Skipped -Because "time to initialise context skews the time on the first test"
        }

        It 'Should throw when more than one controller attribute is present on a class' {

            $expectedErrorMessage = 'Controller1: Invalid number of [Controller] attributes (2)'

            Invoke-TestModuleLoadAsJob -ClassPath ([IO.Path]::Combine($PSScriptRoot, 'Controllers', 'StartupErrors', 'MultipleControllerAttributes')) | Should Be $expectedErrorMessage
        }
    }

    Context 'No routes' {

        It 'Context initialization time' {

            Set-ItResult -Skipped -Because "time to initialise context skews the time on the first test"
        }

        It 'Should throw if controller classes are loaded but no routes defined' {

            $expectedErrorMessage = 'No routes defined.'

            Invoke-TestModuleLoadAsJob -ClassPath ([IO.Path]::Combine($PSScriptRoot, 'Controllers', 'StartupErrors', 'NoRoutes')) | Should Be $expectedErrorMessage
        }
    }
}