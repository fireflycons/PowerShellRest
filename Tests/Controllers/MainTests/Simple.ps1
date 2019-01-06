[Controller()]
class SimpleController
{
    SimpleController()
    {
    }

    [Route('/{val:int}')]
    [object]GetInt([int]$val)
    {
        return $val
    }

    [Route('/{stringVal}/{intVal:int}')]
    [object]GetStringAndInt([string]$stringVal, [int]$intVal)
    {
        return New-Object PSObject -Property @{
            stringVal = $stringVal
            intVal = $intVal
        }
    }
}