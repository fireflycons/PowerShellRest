function Assert-NumberOfItemsInPipeline
{
    <#
    .SYNOPSIS
        Test number of items passed through the pipeline

    .PARAMETER Item
        Item(s) being piped

    .PARAMETER Min
        Minimum number of items that should be passed

    .PARAMETER Max
        Maximum number of items that should be passed

    .PARAMETER Message
        Text to include in exception message

    .OUTPUTS
        The input items
    #>
    [cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $true)] $Item,

        [UInt32]$Min = 0,

        [UInt32]$Max = [UInt32]::MaxValue,

        [Parameter(Position = 0)]
        [string] $Message = "items"
    )

    begin
    {
        [UInt32]$count = 0
    }
    process
    {
        # Check max here so we do not send more items than we want
        if (++$count -gt $Max)
        {
            throw "Exceeded maximum $Max $Message"
        }

        $Item
    }
    end
    {
        if($count -lt $Min)
        {
            throw "Got $count $Message when expected at least $Min"
        }
    }
}