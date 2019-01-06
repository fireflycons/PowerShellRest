function New-ControllerTable
{
    <#
    .SYNOPSIS
        Load user controller classes
#>
    Write-OperatingSystemLogEntry -EventId ([EventId]::InitializationStep) -Message "Loading user controllers"

    # Every .PS1 file containing classes is compiled to a separate in-memory module
    # Search these modules to find types that have the [Controller] attribute

    $controllerTable = [AppDomain]::CurrentDomain.GetAssemblies() |
        Sort-Object -Unique -Property FullName |
        Where-Object {
        # Search all assemblies in AppDomain to find <In Memory Module>
        $_.Modules.Name -icontains '<In Memory Module>'
    } |
        ForEach-Object {

        $_.DefinedTypes |
            Where-Object {
            $_.IsPublic -and (
                $null -ne ($_.GetCustomAttributes('Controller') |
                        Where-Object {
                        $_ -is [Controller]
                    }
                )
            )
        }
    } |
        ForEach-Object {

        # Types that get this far are those with the [Controller] attribute
        [ControllerEntry]::new($_)
    } |
        Sort-Object -Unique ControllerClassName |
        Group-Object -Property { $_.GetHashCode() } |
        Foreach-Object {

        # Finally for duplicate route/verb in the classes we found
        if ($_.Count -gt 1)
        {
            $controllers = ($_.Group |
                    ForEach-Object {

                    $_.ToString()
                }) -join ', '

            throw "($controllers) define the same base route."
        }
        else
        {
            $_.Group |
                Where-Object {
                $_.HasRoutes()
            }
        }
    }

    $numControllers = ($controllerTable | Measure-Object).Count

    # If there's no routes defined, exit
    if ($numControllers -eq 0)
    {
        throw 'No routes defined.'
    }

    Write-OperatingSystemLogEntry -EventId ([EventId]::InitializationStep) -Message "Loading user controllers complete. $numControllers controller(s) loaded."

    # Return controllers
    $controllerTable
}