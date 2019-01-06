[![Build status](https://ci.appveyor.com/api/projects/status/fweuumbkxs0r79um/branch/master?svg=true)](https://ci.appveyor.com/project/fireflycons/powershellrest)

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
