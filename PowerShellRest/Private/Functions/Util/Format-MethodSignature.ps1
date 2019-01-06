function Format-MethodSignature
{
<#
    .SYNOPSIS
        Formats a method signature

    .DESCRIPTION
        Given an instance of MethodInfo, format the human-readable .NET method signature from it

    .PARAMETER Method
        [MethodInfo] object describing the method

    .OUTPUTS
        [string] e.g, 'String MyMethod(Int32 a, Int32 b)'
#>
    param
    (
        [System.Reflection.MethodInfo]$Method
    )

    $Method.ReturnType.Name + ' ' + $Method.ReflectedType.Name + '.' + $Method.Name + '(' + ((
        $Method.GetParameters() |
        Foreach-Object {
            $_.ParameterType.Name + ' ' + $_.Name
        }
    ) -join ', ' ) + ')'
}