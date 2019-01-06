[Controller()]
class Controller1
{
    [Route('/x/{val}')]
    [HttpGet()]
    [HttpPost()]
    [object]method1([int]$val)
    {
        return $null
    }
}