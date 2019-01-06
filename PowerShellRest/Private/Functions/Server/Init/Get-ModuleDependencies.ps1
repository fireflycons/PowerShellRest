function Get-ModuleDependencies
{
<#
    .SYNOPSIS
        Read names of modules to preload from any ModuleDependencies files

    .DESCRIPTION
        Modules found in ModuleDependencies files will be pre-loaded into the initial session state
        for all runspaces used for servicing HTTP requests.
        This prevents slow-downs caused by scripts calling Import-Module while processing a request.
        These modules must be installed modules, i.e. be able to be found in PSModulePath

        This function will verify the existence of any required modules and throw if they cannot be found.

    .PARAMETER ClassPath
        List of paths to user controller code

    .OUTPUTS
        List of module names
#>
    param
    (
        [string[]]$ClassPath
    )

    Write-OperatingSystemLogEntry -EventId ([EventId]::InitializationStep) -Message "Reading ModuleDependecies.txt"

    $requiredModules = $ClassPath |
    Foreach-Object {

        Get-ChildItem -Recurse -Path $_ -Filter ModuleDependencies.txt |
        Foreach-Object {

            Get-Content $_.FullName |
            Foreach-Object {

                if ($_ -notmatch '^\s*#')
                {
                    # Emit module name
                    ($_ -split '#')[0].Trim()
                }
            }
        }
    } |
    Where-Object {
        -not [string]::IsNullOrEmpty($_)
    } |
    Sort-Object -Unique

    if (($requiredModules | Measure-Object).Count -gt 0)
    {
        # Verify all the requested modules are available
        $installedModules = Get-Module -ListAvailable | Select-Object -ExpandProperty Name

        $requiredModules |
        Foreach-Object {

            if ($installedModules -inotcontains $_)
            {
                throw "Module $_ cannot be found on this system."
            }
        }

        Write-OperatingSystemLogEntry -EventId ([EventId]::InitializationStep) -Message "Found modules: $($requiredModules -join ', ')"
    }
    else
    {
        Write-OperatingSystemLogEntry -EventId ([EventId]::InitializationStep) -Message "No modules found."
    }

    $requiredModules
}