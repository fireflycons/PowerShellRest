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

    $loadedModules = Get-Module | Select-Object Name, Version

    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows))
    {
        $requiredModules = @(
            New-Object PSObject -Property @{
                Name            = 'psake'
                RequiredVersion = [Version]'4.7.4'
            }
            New-Object PSObject -Property @{
                Name            = 'Pester'
                RequiredVersion = [Version]'4.5.0'
            }
            New-Object PSObject -Property @{
                Name            = 'BuildHelpers'
                RequiredVersion = [Version]'2.0.7'
            }
            New-Object PSObject -Property @{
                Name            = 'platyPS'
                RequiredVersion = [Version]'0.12.0'
            }
            New-Object PSObject -Property @{
                Name            = 'PSDeploy'
                RequiredVersion = [Version]'1.0.1'
            }
        )
    }
    else
    {

        if ($Task -ine 'Test')
        {
            throw 'Only testing supported on non-windows environment'
        }

        $requiredModules = @(
            New-Object PSObject -Property @{
                Name            = 'psake'
                RequiredVersion = [Version]'4.7.4'
            }
            New-Object PSObject -Property @{
                Name            = 'Pester'
                RequiredVersion = [Version]'4.5.0'
            }
            New-Object PSObject -Property @{
                Name            = 'BuildHelpers'
                RequiredVersion = [Version]'2.0.7'
            }
        )
    }

    # List of modules not already loaded
    $missingModules = Compare-Object -ReferenceObject $requiredModules.Name -DifferenceObject $loadedModules.Name |
        Where-Object {
        $_.SideIndicator -eq '<='
    } |
        Select-Object -ExpandProperty InputObject

    if ($missingModules)
    {
        $installedModules = Get-Module -ListAvailable |
            Select-Object Name, Version

        $neededModules = $requiredModules |
            Where-Object {
            $r = $_
            -not ($installedModules | Where-Object {
                    $_.Name -eq $r.Name -and $_.Version -ge $r.RequiredVersion
                })
        }

        $neededModules |
            ForEach-Object {
            Write-Host "Installing module: $($_.Name) $($_.RequiredVersion)"
            Install-Module -Name $_.Name -RequiredVersion $_.RequiredVersion -Force -AllowClobber -SkipPublisherCheck -Scope CurrentUser
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