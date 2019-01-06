<#
    Controller class for testing module preload functionality
#>
[Controller()]
class ModuleDependenciesController
{
    ModuleDependenciesController()
    {
    }

    # Tests whether the named module is preloaded
    [Route('/{moduleName:string}')]
    [object]IsModuleLoaded([string]$moduleName)
    {
        return $null -ne (Get-Module $moduleName -ErrorAction SilentlyContinue)
    }
}