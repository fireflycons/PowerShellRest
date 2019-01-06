function Assert-ThreadErrors
{
    param
    (
        [powershell]$Thread
    )

    $sb = [System.Text.StringBuilder]::new()

    $Thread.Streams.Error |
    Foreach-Object {
        $sb.AppendLine($_.Exception.Message) | Out-Null
    }

    if ($sb.Length -gt 0)
    {
        throw $sb.ToString()
    }
}