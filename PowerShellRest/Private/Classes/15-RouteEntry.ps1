<#
    Represents an argument parsed from the path declared by the Route attribute
#>
class RouteArgument
{
    # Argument name i.e. 'id' from {id}
    [string]$Name

    # Decalred datatpye, or object if none e.g. {id:intr
    [type]$DataType

    # Ordered position within the route
    [int]$Position
    RouteArgument([string]$name, [type]$type, [int]$position)
    {
        $this.Name = $name
        $this.DataType = $type
        $this.Position = $position
    }

    [string]ToString()
    {
        return "$($this.DataType.Name) $($this.Name)"
    }
}

<#
    This class represnts a route mapping.
    It maps a route (/controller/method/{arg}) to a controller class method
    and is used to select and to inovke a route an incoming request
#>
class RouteEntry
{
    # Regex to match numbers
    hidden static [System.Text.RegularExpressions.Regex]$NumberRegex = [System.Text.RegularExpressions.Regex]::new('^[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$')

    # Regex to match arguments (name with optional data type) from the value of a Route() attribute
    hidden static [System.Text.RegularExpressions.Regex]$TokenRx = [System.Text.RegularExpressions.Regex]::new('\{(?<token>\w+)(:(?<datatype>\w+))?\}')

    # Built by the constructor, this is the regex that is used to match an incoming request path with this RouteEntry instance
    hidden [System.Text.RegularExpressions.Regex]$RouteMatcherRx

    # The method that will be called if this RouteEntry is selected
    hidden [System.Reflection.MethodInfo]$Method

    # Arguments to the above method
    hidden [System.Reflection.ParameterInfo[]]$MethodArguments

    # Value to return for GetHashCode()
    hidden [int]$HashCode

    # Number of segments in the route path
    hidden [int]$PathSegmentCount

    # HTTP verb the route is associated with
    [string]$RequestMethod

    # The full route, including controller prefix
    [string]$Route

    # Arguments parsed from the Route attribute's path
    [RouteArgument[]]$RouteArguments

    <#
        Hide default constructor
    #>
    hidden RouteEntry()
    {
    }

    <#
        Construct route entry
    #>
    RouteEntry([string]$controllerPrefix, [System.Reflection.MethodInfo]$method, [HttpRequestMethod]$requestMethod, [Route]$route)
    {
        if ($method.ReturnType -eq [void])
        {
            # All route controller methods must return something - usually Object
            throw "$(Format-MethodSignature -Method $method) - void return type not allowed."
        }

        $this.Method = $method
        $this.MethodArguments = $method.GetParameters()
        $this.RequestMethod = $requestMethod.RequestMethod

        $this.Route = ($controllerPrefix + '/' + $route.Route.Trim('/')).TrimEnd('/')
        $this.PathSegmentCount = ($this.Route -split '/').Length

        # Parse the route
        $mc = [RouteEntry]::TokenRx.Matches($this.Route)

        $argList = [System.Collections.Generic.List[RouteArgument]]::new()

        $position = 0
        $mc |
            ForEach-Object {

            $argumentName = $_.Groups['token'].Value

            # Check method has a matching argument
            if (-not ($this.MethodArguments | Where-Object { $_.Name -eq $argumentName}))
            {
                throw "$(Format-MethodSignature -Method $method) does not contain a parameter named '$argumentName'"
            }

            if ($_.Groups['datatype'].Success)
            {
                # If an explicit datatype was provided on the route, check the method argument is that type
                $dataType = Invoke-Expression ["$($_.Groups['datatype'].Value)"]

                if (-not ($this.MethodArguments | Where-Object {$_.Name -eq $argumentName -and $_.ParameterType -eq $dataType}))
                {
                    throw "$(Format-MethodSignature -Method $method) does not contain a parameter named '$argumentName' with type '$($dataType.Name)'"
                }
            }
            else
            {
                $dataType = [object]
            }

            $argList.Add((New-Object RouteArgument ($argumentName, $dataType, $position++)))
        }

        $this.RouteArguments = $argList.ToArray()
        $this.RouteMatcherRx = New-Object System.Text.RegularExpressions.Regex ([RouteEntry]::TokenRx.Replace($this.Route, '([\w+~\.\-\%\@]+)'))
        $this.HashCode = ($this.RequestMethod + $this.route.ToLowerInvariant()).GetHashCode();
    }

    <#
        Score a path against this route entry.
        The higher the score, the better the match.
        A score of zero is a definite no-match
    #>
    [int]MatchScore([string]$route)
    {
        # First, and quickest check - this RouteEntry and input route have the same number of path segments?
        if ($this.PathSegmentCount -ne ($route -split '/').Length)
        {
            return 0
        }

        # Try to match the route by regex
        $match = $this.RouteMatcherRx.Match($route)

        if (-not $match.Success)
        {
            return 0
        }

        # Number of parameters in route matched by regex is not the same as the number of route arguments we expect?
        # Match group zero is the entire string.
        if ($match.Groups.Count - 1 -ne $this.RouteArguments.Length)
        {
            return 0
        }

        # Route with no arguments
        if ($this.RouteArguments.Length -eq 0)
        {
            return 100
        }

        $score = 0

        for ($i = 0; $i -lt $match.Groups.Count - 1; ++$i)
        {
            # Route argument array is in the same order as the matches in the match collection
            $routeArg = $this.RouteArguments[$i]

            # If the route argument has a data type that implements Parse(), then test if the value is parseable
            if (([object], [string]) -notcontains $routeArg.DataType)
            {
                try
                {
                    # Try parsing the matched path segment as the required datatype (which must be s simple value type) for the route argument

                    # Match group containing matched argument value
                    $thisSegmentValue = $match.Groups[$i + 1].Value
                    Invoke-Expression("[$($routeArg.DataType.FullName)]::Parse(`'$thisSegmentValue`')")

                    # The value was parsed as type for the argument - that's an exact match so continue along the path
                    $score += 100
                    continue
                }
                catch
                {
                    # Failed to parse - no match.
                    return 0
                }
            }

            # Get corresponding controller method argument by name
            $methodArg = $this.MethodArguments | Where-Object { $_.Name -eq $routeArg.Name }

            $argumentIsString = -not ([RouteEntry]::NumberRegex.IsMatch($match.Groups[$i + 1].Value))

            $parameterIsString = $methodArg.ParameterType -eq [string]

            if ($argumentIsString -and $parameterIsString)
            {
                $score += 100
                continue
            }

            if ($routeArg.DataType -eq [object])
            {
                # Lowest quality match
                $score += 1
                continue
            }

            if ($routeArg.DataType -eq [string])
            {
                # Next lowest quality
                $score += 10
                continue
            }

        }

        return $score
    }

    <#
        Invoke class method for this route, returning its result.
    #>
    [object]Invoke([string]$route)
    {
        # type[] with no contents to select controller class default constructor
        $typeArr = New-Object Type[] 0

        # object[] with no contents to use to invoke controller class default constructor
        $objArr = New-Object object[] 0

        # Get constructor
        $ctor = $this.Method.ReflectedType.GetConstructor($typeArr)

        if (-not $ctor)
        {
            throw "Cannot find default constructor for $($this.Method.ReflectedType)"
        }

        # Get controller class instance
        $controller = $ctor.Invoke($objArr)

        # Now collect the values to pass to the selected method
        $methodArgumentValues = [System.Collections.Generic.List[object]]::new()

        # This will match, as this RouteEntry was selected by this regex
        $match = $this.RouteMatcherRx.Match($route)

        for ($i = 0; $i -lt $this.MethodArguments.Length; ++$i)
        {
            # For each method argument, in order
            $methodArg = $this.MethodArguments[$i]

            # Get the corresponding route argument and hence its position in the match
            $routeArg = $this.RouteArguments | Where-Object { $_.Name -eq $methodArg.Name }
            $value = $match.Groups[$routeArg.Position + 1].Value

            # Now parse the value as the appropriate type for the method argument
            if (([string], [object]) -contains $methodArg.ParameterType)
            {
                # Add the string value for a method argument of type string or object
                $methodArgumentValues.Add(([System.Web.HttpUtility]::UrlDecode($value)))
            }
            else
            {
                # Try to parse the value as the correct type for the method argument
                $methodArgumentValues.Add((Invoke-Expression "[$($methodArg.ParameterType.FullName)]::Parse(`'$value`')"))
            }
        }

        # Invoke the method
        try
        {
            return $this.Method.Invoke($controller, $methodArgumentValues.ToArray())
        }
        catch
        {
            # Add a note property to the exception with the method signature that was invoked (see exception handling in Invoke-Route)
            Add-Member -InputObject $_.Exception -MemberType NoteProperty -Name 'InvokedMethodSignature' -Value (Format-MethodSignature -Method $this.Method)
            throw
        }

        return $null
    }

    [int]GetHashCode()
    {
        return $this.HashCode
    }

    [string]ToString()
    {
        return (Format-MethodSignature -Method $this.Method)
    }
}