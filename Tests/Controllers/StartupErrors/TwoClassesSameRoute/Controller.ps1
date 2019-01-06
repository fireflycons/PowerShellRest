[Controller('throwme')]
class Controller1
{
    [Route('/x/{val}')]
    [object]Method1([int]$val)
    {
        return $null
    }
}

[Controller('throwme')]
class Controller2
{
    [Route('/x/{val}')]
    [object]Method2([int]$val)
    {
        return $null
    }
}
