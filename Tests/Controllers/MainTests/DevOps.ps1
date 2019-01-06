# Devops-y type controllers

<#
    This controller class has two routes that are similar in that they have the same number of 
    segments with with the same number of arguments in the same places.

    This will show best-matching of routes between GetProcessByName and GetProcessById

    If the second route argument is an integer, and within valid range for Int32, then GetProcessById is selected
    However, if the argument is e.g. [long]::MaxValue, then {id:int} will not match but {name:string} will as a lower quality match.
#>
[Controller('/process')]
class ProcessController
{
    static [bool]$IsUnix = -not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)

    [Route('/{computerName}')]
    [HttpGet()]
    [object]GetProcesses([string]$computerName)
    {
        # Return only the standard fields as per Get-Process's format definition for speed.
        if ([ProcessController]::IsUnix)
        {
            # PS Core on Unix doesn't support -ComputerName
            if (-not ([ProcessController]::IsLocalMachine($computerName)))
            {
                throw 'Cannot get process for remote comuter'
            }

            return Get-Process | Select-Object Id, Name, Handles, NPM, PM, WS, CPU, SI
        }
        else
        {
            return Get-Process -ComputerName $computerName | Select-Object Id, Name, Handles, NPM, PM, WS, CPU, SI
        }
    }

    [Route('/{computerName}/{name:string}')]
    [HttpGet()]
    [object]GetProcessByName([string]$computerName, [string]$name)
    {
        if ([ProcessController]::IsUnix)
        {
            # PS Core on Unix doesn't support -ComputerName
            if (-not ([ProcessController]::IsLocalMachine($computerName)))
            {
                throw 'Cannot get process for remote comuter'
            }

            return Get-Process -Name $name
        }
        else
        {
            return Get-Process -ComputerName $computerName -Name $name
        }
    }

    [Route('/{computerName}/{id:int}')]
    [HttpGet()]
    [object]GetProcessById([string]$computerName, [int]$id)
    {
        if ([ProcessController]::IsUnix)
        {
            # PS Core on Unix doesn't support -ComputerName
            if (-not ([ProcessController]::IsLocalMachine($computerName)))
            {
                throw 'Cannot get process for remote comuter'
            }

            return Get-Process -Id $id
        }
        else
        {
            return Get-Process -ComputerName $computerName -Id $id
        }
    }

    static [bool]IsLocalMachine([string]$computername)
    {
        if ($computername -eq '.')
        {
            return true
        }

        return (($computername -split '\.')[0] -ieq [System.Environment]::MachineName)
    }
}

[Controller('/service')]
class ServiceController
{
    [Route('/{computerName}')]
    [HttpGet()]
    [object]GetServices([string]$computerName)
    {
        return Get-Service -ComputerName $computerName
    }

    [Route('/{computerName}/{name:string}')]
    [HttpGet()]
    [object]GetServiceByName([string]$computerName, [string]$name)
    {
        return Get-Service -ComputerName $computerName -Name $name
    }
}

