# Pester tests for the module
# THis has to be last, or it causes weird errors in ControllerEntry class
$ModuleName = 'PowerShellRest'

Get-Module -Name $ModuleName | Remove-Module

# Find the Manifest file
$ManifestFile = (Resolve-Path ([IO.Path]::Combine($PSScriptRoot, '..', 'PowerShellRest', "$ModuleName.psd1"))).Path

# Import the module and store the information about the module
$ModuleInformation = Import-Module -Name $ManifestFile -PassThru

Describe "$ModuleName Module - Testing Manifest File (.psd1)" {

    Context 'Manifest' {

        It 'Context initialization time' {

            Set-ItResult -Skipped -Because "time to initialise context skews the time on the first test"
        }

        It 'Should contain RootModule' {
            $ModuleInformation.RootModule | Should not BeNullOrEmpty
        }
        It 'Should contain Author' {
            $ModuleInformation.Author | Should not BeNullOrEmpty
        }
        It 'Should contain Company Name' {
            $ModuleInformation.CompanyName | Should not BeNullOrEmpty
        }
        It 'Should contain Description' {
            $ModuleInformation.Description | Should not BeNullOrEmpty
        }
        It 'Should contain Copyright' {
            $ModuleInformation.Copyright | Should not BeNullOrEmpty
        }
        It 'Should contain License' {
            $ModuleInformation.LicenseURI | Should not BeNullOrEmpty
        }
        It 'Should contain a Project Link' {
            $ModuleInformation.ProjectURI | Should not BeNullOrEmpty
        }
        It 'Should contain Tags (For the PSGallery)' {
            $ModuleInformation.Tags.count | Should not BeNullOrEmpty
        }
        It 'Should have no whitespace in tag values' {
            $ModuleInformation.Tags |
            ForEach-Object {
                $_ | Should Not Match '\s'
            }
        }
    }
}

Get-Module -Name $ModuleName | Remove-Module

