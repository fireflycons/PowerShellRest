class Customer
{
    static [int]$NextId = 0

    [int]$Id
    [string]$FirstName
    [string]$LastName

    Customer([string]$firstName, [string]$lastName)
    {
        $this.Id = ++[Customer]::NextId
        $this.FirstName = $firstName
        $this.LastName = $lastName
    }
}

[Controller('/customer')]
class CustomerController
{
    static [System.Collections.ArrayList]$CustomerList = (
        New-Object System.Collections.ArrayList (
            ,@(
                New-Object Customer ('Julius', 'Adkins')
                New-Object Customer ('Rickey', 'Houston')
                New-Object Customer ('Lyle', 'Warren')
                New-Object Customer ('Verna', 'Stokes')
                New-Object Customer ('Howard', 'Arnold')
                New-Object Customer ('Lena', 'Hines')
                New-Object Customer ('Tommie', 'Mann')
                New-Object Customer ('Leland', 'Watson')
                New-Object Customer ('Jimmie', 'Zimmerman')
                New-Object Customer ('Terry', 'Bates')
            )
        )
    )

    [Route('/{id}')]
    [HttpGet()]
    [object]GetCustomer([int]$id)
    {
        # https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/GET

        $cust = [CustomerController]::CustomerList | Where-Object { $_.Id -eq $id }

        if ($cust)
        {
            return $cust
        }

        return [HttpStatus]::NotFound
    }

    [Route('/')]
    [HttpGet()]
    [object]ListCustomer()
    {
        return [CustomerController]::CustomerList
    }

    [Route('/')]
    [HttpPost()]
    [object]NewCustomer([object]$formData)
    {
        # https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/POST

        try
        {
            [CustomerController]::CustomerList.Add((New-Object Customer ($formData.FirstName, $formData.LastName)))
        }
        catch
        {
            return [HttpStatus]::BadRequest
        }

        return New-Object PSObject -Property @{
            Id = ([CustomerController]::CustomerList | Select-Object -Last 1).Id
        }
    }

    [Route('/{id}')]
    [HttpDelete()]
    [object]DeleteCustomer([int]$id)
    {
        # https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/DELETE
        $cust = [CustomerController]::CustomerList | Where-Object { $_.Id -eq $id }

        if ($cust)
        {
            [CustomerController]::CustomerList.Remove($cust)
        }

        return [HttpStatus]::NoContent
    }

    [Route('/{id}')]
    [HttpPut()]
    [object]UpdateCustomer([int]$id, [object]$formData)
    {
        # https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/PUT

        return [HttpStatus]::NoContent
    }
}