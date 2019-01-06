<#
    Base class for attributes defined in this module
#>
class RestAttribute : Attribute
{
    RestAttribute()
    {
    }
}

<#
    This attribute marks a class as a controller which contains route controllers.

    If declared with no prefix argument, the base path for the controller is determined from the class name
    with any 'Controller' suffix removed from the name, and the name lowercased e.g.
    ProcessController => /process
#>
[AttributeUsage('Class')]
class Controller : RestAttribute
{
    Controller()
    {
        $this.Prefix = [string]::Empty
    }

    Controller([string]$Prefix)
    {
        # Ensure prefix has a leading / and no trailing /
        $this.Prefix = '/' + $Prefix.Trim('/')
    }

    [string]$Prefix

    [string]ToString()
    {
        return $this.Prefix
    }
}

<#
    This attribute marks a method within a controller class as handling a route.
    The attribute value is the route relative path on the controller.
#>
[AttributeUsage('Method', AllowMultiple = $false)]
class Route : RestAttribute
{
    Route([string] $Route)
    {
        $this.Route = $Route
    }

    [string]$Route

    [string]ToString()
    {
        return $this.Route
    }
}

<#
    This attribute is the base class for all HTTP method verbs.
#>
[AttributeUsage('Method', AllowMultiple = $false, Inherited = $true)]
class HttpRequestMethod : RestAttribute
{
    HttpRequestMethod()
    {
    }

    HttpRequestMethod([string]$RequestMethod)
    {
        $this.RequestMethod = $RequestMethod
    }

    [string]$RequestMethod
}

<#
    This attribute marks a method as responding to GET
#>
class HttpGet : HttpRequestMethod
{
    HttpGet() : base('GET')
    {
    }
}

<#
    This attribute marks a method as responding to POST
#>
class HttpPost : HttpRequestMethod
{
    HttpPost()
    {
        $this.RequestMethod = 'POST'
    }
}

<#
    This attribute marks a method as responding to PUT
#>
class HttpPut : HttpRequestMethod
{
    HttpPut()
    {
        $this.RequestMethod = 'PUT'
    }
}

<#
    This attribute marks a method as responding to DELETE
#>
class HttpDelete : HttpRequestMethod
{
    HttpDelete()
    {
        $this.RequestMethod = 'DELETE'
    }
}

