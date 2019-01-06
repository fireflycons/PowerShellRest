[Controller()]
[Controller('/error')]
class Controller1
{
    [Route('/y/{val}')]
    [object]method1([int]$val)
    {
        return $null
    }
}