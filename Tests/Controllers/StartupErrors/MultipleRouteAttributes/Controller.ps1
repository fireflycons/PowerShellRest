[Controller()]
class Controller1
{
    [Route('/x/{val}')]
    [Route('/y/{val}')]
    [object]method1([int]$val)
    {
        return $null
    }
}