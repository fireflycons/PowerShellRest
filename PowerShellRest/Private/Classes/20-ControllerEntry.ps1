<#
    Object that manages a user controller class.
#>
class ControllerEntry
{
    # The user class this controller is associated with
    hidden [type]$ControllerClass

    # The routes declared by the user class
    hidden [RouteEntry[]]$Routes

    # Route prefix for this controller
    [string]$Prefix

    # Full name of the controller class
    [string]$ControllerClassName

    <#
        Constructor - takes type of a user controller
    #>
    ControllerEntry([type]$controllerClass)
    {
        # Read controller attribute from user class
        $controllerAttr = $controllerClass.GetCustomAttributes('Controller') | Where-Object { $_ -is [Controller] }

        if (@($controllerAttr).Length -ne 1)
        {
            throw "$($controllerClass.Name): Invalid number of [Controller] attributes ($(@($controllerAttr).Length))"
        }

        $this.ControllerClass = $controllerClass
        $this.ControllerClassName = $controllerClass.FullName

        # Determine route prefix
        $this.Prefix = $(
            if ([string]::IsNullOrEmpty($controllerAttr.Prefix))
            {
                # If the controller class was declared with [Controller()], i.e. no defined prefix...

                $controllerLength = 'Controller'.Length
                $className = $controllerClass.Name

                if ($className.Length -gt $controllerLength -and $className.EndsWith('Controller', 'OrdinalIgnoreCase'))
                {
                    # If name of controller class ends with 'Controller' then the prefix is the class name in lowercase with 'Controller' removed.
                    # e.g. MyController -> /my
                    "/$($className.Substring(0, $className.Length - $controllerLength).ToLowerInvariant())"
                }
                else
                {
                    "/$($className.ToLowerInvariant())"
                }
            }
            else
            {
                $controllerAttr.Prefix
            }
        )

        # Build the route list from the controller class
        $routeList = [System.Collections.Generic.List[RouteEntry]]::new()

        $controllerClass.GetMethods() |
            ForEach-Object {

            $method = $_
            $attr = $method.GetCustomAttributes($true) | Where-Object { $_ -is [RestAttribute] }

            # If method has any rest attribute on it, then process
            if ($attr)
            {
                # String representation of controller method for messages
                $methodName = Format-MethodSignature -Method $method

                # Get verb and route
                $verbs = $attr | Where-Object { $_ -is [HttpRequestMethod] }
                $routes = $attr | Where-Object { $_ -is [Route] }

                if (@($verbs).Count -gt 1)
                {
                    # Seems that PowerShell ignores the AttrinuteUsage attribute
                    throw "$methodName - Multiple HTTP Verbs not allowed."
                }
                elseif (@($verbs).Count -eq 0)
                {
                    # Default GET
                    $verbs = New-Object HttpGet
                }

                if (($routes | Measure-Object).Count -gt 1)
                {
                    throw "$methodName - Multiple routes not allowed."
                }
                elseif (($routes | Measure-Object).Count -eq 0)
                {
                    # It has a verb or we wouldn't get here
                    throw "$methodName - Missing route attribute"
                }

                $routeList.Add([RouteEntry]::new($this.Prefix, $method, $verbs, $routes))
            }
        }

        # Test for duplicate routes
        $routeList |
            Group-Object -Property { $_.GetHashCode() } |
            Foreach-Object {

            # Finally for duplicate route/verb in the classes we found
            if ($_.Count -gt 1)
            {
                $methods = ($_.Group |
                        ForEach-Object {

                        $_.ToString()
                    }) -join ', '

                throw "($methods) define the same route: $($_.Group[0].RequestMethod) $($_.Group[0].Route)"
            }
        }

        $this.Routes = $routeList.ToArray()
    }

    <#
        Given a request path that matches this controller class, select the best route on this controller that matches the path
        Return zero or one route. If one route, it will be the one with the highest score
        See RouteEntry::MatchScore()
    #>
    [RouteEntry]GetRoute([string]$requestMethod, [string]$path)
    {
        $candidates =  $this.Routes |
            Where-Object {
                if ($requestMethod -ieq 'HEAD')
                {
                    # Redirect HEAD requests to GET routes
                    $_.RequestMethod -ieq 'GET'
                }
                else
                {
                    $_.RequestMethod -ieq $requestMethod
                }
        } |
            ForEach-Object {
            New-Object PSObject -Property @{
                Score = $_.MatchScore($path)
                Route = $_
            }
        }

        return $candidates |
            Where-Object {$_.Score -gt 0 } |
            Sort-Object -Property Score -Descending |
            Select-Object -First 1 |
            Select-Object -ExpandProperty Route
    }

    [string[]]GetRouteOptions([string]$Path)
    {
        $candidates =  $this.Routes |
            ForEach-Object {
            New-Object PSObject -Property @{
                Score = $_.MatchScore($path)
                Route = $_
            }
        } |
        Group-Object -Property Score |
        Sort-Object -Property @{ Expression = { [int]($_.Name) } ; Descending = $true } |
        Select-Object -First 1

        if (($candidates | Measure-Object).Count -eq 0)
        {
            # No matching routes
            return $null
        }

        $retval = @($candidates.Group.Route.RequestMethod) + 'OPTIONS'

        if ($retval -icontains 'GET')
        {
            $retval += 'HEAD'
        }

        return $retval | Sort-Object -Unique
    }

    [string]ToString()
    {
        return "$($this.ControllerClass.Name) [$($this.Prefix)]"
    }

    <#
        We use the hash code to detect controllers defining the same prefix in New-ControllerTable
    #>
    [int]GetHashCode()
    {
        return $this.Prefix.ToLowerInvariant().GetHashCode()
    }

    [bool]HasRoutes()
    {
        return $null -ne $this.Routes -and $this.Routes.Length -gt 0
    }
}