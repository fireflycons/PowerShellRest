param
(
    [string]$ClassPath,

    [ValidatePattern('^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')]
    [string]$BoundIp = '0.0.0.0',

    [UInt16]$Port,

    [switch]$MultiThreaded,

    [switch]$Service
)

Import-Module ((Resolve-Path ([IO.Path]::Combine($PSScriptRoot, '..', 'PowerShellRest', "$ModuleName.psd1"))).Path) -ArgumentList $ClassPath

Start-RestServer @PSBoundParameters