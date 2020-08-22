[![Build status](https://ci.appveyor.com/api/projects/status/fweuumbkxs0r79um/branch/master?svg=true)](https://ci.appveyor.com/project/fireflycons/powershellrest)

![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PowerShellRest)

# PowerShellRest

A RESTful server written in pure PowerShell.

## Intended Use

I developed this primarily as a data source for building internal dashboards, the idea being that you can quickly knock up a set of scripts containing PowerShell classes that can export JSON data to be consumed by an internal web site.

It is also an exercise in writing an HTTP server from the ground-up, and use of classes, attributes and multithreading in PowerShell.

## What it isn't

This implemenation contains no security features!

It currently does not support any of the following, therefore is not suitable for use as an internet-facing API server.

* Authentication
* Native HTTPS endpoints
* CORS - All CORS requests will be allowed.

It could possibly be hidden behind a commercial API gateway to provide these features.

# Example Usage

## Start the server

This will start the server using the controller classes used by the Pester tests. It assumes you are in the directory into which you've cloned this repo, and that you installed the module from PSGallery

Open a PowerShell prompt and run the following

```powershell
Import-Module PowerShellRest
Start-RestServer -Port 8080 -ClassPath Tests/Controllers/MainTests -Service
```

## Run API calls

Wait for the service to print a message to say it has started, then open another PowerShell prompt.  The third call to return running operating system processes assumes you're running on Windows.

```powershell
Invoke-RestMethod http://localhost:8080/customer
Invoke-RestMethod http://localhost:8080/customer/1
Invoke-RestMethod "http://localhost:8080/process/$env:COMPUTERNAME"
```

To stop the server, run this

```powershell
Invoke-Restmethod http://localhost:8080/exception/kill
```


