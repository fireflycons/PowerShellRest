param
(
    $Task = 'Default'
)

$currentLocation = Get-Location
try
{
    Set-Location $PSScriptRoot

    # Grab nuget bits, install modules, set build variables, start build.
    Write-Host 'Setting up build environment'
    Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

    $loadedModules = Get-Module | Select-Object -ExpandProperty Name

    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows))
    {
        $requiredModules = @(
            'Psake'
            'PSDeploy'
            'BuildHelpers'
            'platyPS'
            'Pester'
        )
    }
    else
    {

        if ($Task -ine 'Test')
        {
            throw 'Only testing supported on non-windows environment'
        }

        $requiredModules = @(
            'Psake'
            'BuildHelpers'
            'Pester'
        )
    }

    # List of modules not already loaded
    $missingModules = Compare-Object -ReferenceObject $requiredModules -DifferenceObject $loadedModules |
        Where-Object {
        $_.SideIndicator -eq '<='
    } |
        Select-Object -ExpandProperty InputObject

    if ($missingModules)
    {
        $installedModules = Get-Module -ListAvailable | Select-Object -ExpandProperty Name

        $neededModules = $requiredModules |
            Where-Object {
            -not ($installedModules -icontains $_)
        }

        if (($neededModules | Measure-Object).Count -gt 0)
        {
            Write-Host "Installing modules: $($neededModules -join ',')"
            Install-Module $neededModules -Force -AllowClobber -SkipPublisherCheck -Scope CurrentUser
        }

        Write-Host "Importing modules: $($missingModules -join ',')"
        Import-Module $missingModules
    }

    Set-BuildEnvironment -ErrorAction SilentlyContinue

    Invoke-psake -buildFile (Join-Path $PSScriptRoot psake.ps1) -taskList $Task -nologo
    exit ( [int]( -not $psake.build_success ) )
}
catch
{
    Write-Error $_.Exception.Message

    # Make AppVeyor fail the build if this setup borks
    exit 1
}
finally
{
    Set-Location $currentLocation
}