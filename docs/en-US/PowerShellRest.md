---
Module Name: PowerShellRest
Module Guid: 3943cc13-7570-4c31-8739-13712bf51146
Download Help Link: {{Please enter FwLink manually}}
Help Version: 1.0.0.0
Locale: en-US
---

# PowerShellRest Module
## Description
A RESTful server built in pure PowerShell

## PowerShellRest Cmdlets
### [Initialize-EventLogging](Initialize-EventLogging.md)
Creates or opens the event logging source for the application.
If the event source does not exist, the caller must have sufficient rights to create an event source.
If the account you intend to run the service as does not have these rights, load the module in
a console session as Administrator and call this function manually.


### [Resolve-Request](Resolve-Request.md)
Do not call this function directly.

This function has to be part of the public API as it is called from outside of the module scope
by the thread that listens for incoming requests.

### [Start-RestServer](Start-RestServer.md)
This is the main method for starting up a new server.


