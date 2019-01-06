function Get-Route
{
<#
    .SYNOPSIS
        Given verb and URI path, find matching route

    .PARAMETER RequestMethod
        HTTP verb, e.g. GET

    .PARAMETER Path
        Request path

    .OUTPUTS
        [RouteEntry] - Best matched route, or $null if no match.

    .NOTES
        Exception is thrown if multiple routes match.

#>
    param
    (
        [string]$RequestMethod,
        [string]$Path
    )

    if ($Path.IndexOf('?') -gt -0)
    {
        # Strip any query parameters
        $Path = $Path.Substring(0, $Path.IndexOf('?'))
    }

    if ($Path -ne '/')
    {
        $Path = $Path.TrimEnd('/')
    }

    $controller = $script:ControllerTable |
    Where-Object {
        $Path.StartsWith($_.Prefix, 'OrdinalIgnoreCase')
    } |
    Assert-NumberOfItemsInPipeline -Max 1 "controller matches" # If this throws, then 500 error

    if ($controller)
    {
        $controller.GetRoute($RequestMethod, $Path)
    }
    else
    {
        # 404
        $null
    }
}