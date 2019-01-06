function Get-UnderlyingException
{
<#
    .SYNOPSIS
        Get the 'actual' exception that is packaged in all the PowerShell exception gubbins

    .DESCRIPTION
        When an exception is thrown by a method that was invoked by reflection, the actual exception raised is embeedded thus
        MethodInvocationException
        - RuntimeException
          - Actual exception thrown

    .PARAMETER Exception
        The exception to examine

    .OUTPUTS
        If the structure is as described, then the actual inner exception; else the exception passed to the -Exception argument
#>
    param
    (
        [Exception]$Exception
    )

    $ex = $Exception

    if ($ex -is [System.Management.Automation.MethodInvocationException])
    {
        $ex = $ex.InnerException

        if ($ex -is [System.Management.Automation.RuntimeException] -and $ex.InnerException)
        {
            return $ex.InnerException
        }
    }

    $Exception
}

