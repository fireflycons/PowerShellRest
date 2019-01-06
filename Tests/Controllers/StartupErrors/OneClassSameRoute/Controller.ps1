[Controller()]
class Controller1
{
    [Route('/x/{val}')]
    [object]Method1([int]$val)
    {
        return $null
    }

    [Route('/x/{val}')]
    [object]Method2([int]$val)
    {
        return $null
    }
}
