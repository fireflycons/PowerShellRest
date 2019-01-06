
$moduleName = 'PowerShellRest'
$modulePath = (Resolve-Path ([IO.Path]::Combine($PSScriptRoot, '..', 'PowerShellRest', "$ModuleName.psd1"))).Path

Get-Module -Name $ModuleName | Remove-Module

Import-Module $modulePath

InModuleScope -ModuleName $moduleName {

    Describe 'Private functions' {

        Context 'Get-ModuleDepencencies' {

            It 'Context initialization time' {

                # Swallow up the time to initialise  context which skews the time on the first test.
            }

            It 'Should find a module that exists' {

                'Pester' | Out-File -FilePath testdrive:\ModuleDependencies.txt
                Get-ModuleDependencies -ClassPath testdrive:\ModuleDependencies.txt | Should Be 'Pester'
            }

            It 'Should de-dupe multiple occurences of same module' {

                "Pester`nPester" | Out-File -FilePath testdrive:\ModuleDependencies.txt
                Get-ModuleDependencies -ClassPath testdrive:\ModuleDependencies.txt | Should Be 'Pester'
            }

            It 'Should ignore comments' {

                "#Comment`nPester # Another comment" | Out-File -FilePath testdrive:\ModuleDependencies.txt
                Get-ModuleDependencies -ClassPath testdrive:\ModuleDependencies.txt | Should Be 'Pester'
            }

            It 'Should throw if a module does not exist' {

                'ThisModuleDoesNotExist' | Out-File -FilePath testdrive:\ModuleDependencies.txt
                { Get-ModuleDependencies -ClassPath testdrive:\ModuleDependencies.txt } | Should Throw
            }
        }
    }

    Describe 'Compression' {

        ('GZip', 'Deflate') |
        Foreach-Object {

            $compressionMethod = $_

            Context $compressionMethod {

                It 'Context initialization time' {

                    # Swallow up the time to initialise  context which skews the time on the first test.
                }

                It 'Should compress and decompress text' {

                    $expectedText = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ridiculus mus mauris vitae ultricies leo integer malesuada nunc vel.'

                    $compressor = New-Compressor -Algorithm $compressionMethod
                    $compressed = $compressor.Compress($expectedText)
                    $actualText = $compressor.Decompress($compressed)

                    $actualText | Should Be $expectedText
                }
            }
        }
    }
}
