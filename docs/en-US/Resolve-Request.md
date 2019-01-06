---
external help file: PowerShellRest-help.xml
Module Name: PowerShellRest
online version:
schema: 2.0.0
---

# Resolve-Request

## SYNOPSIS
Handles an incoming request

## SYNTAX

```
Resolve-Request [[-TcpClient] <TcpClient>] [[-CancellationTokenSource] <CancellationTokenSource>]
```

## DESCRIPTION
Do not call this function directly.

This function has to be part of the public API as it is called from outside of the module scope
by the thread that listens for incoming requests.

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -TcpClient
A connected TcpClent object representing the client making the request.

```yaml
Type: TcpClient
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CancellationTokenSource
The token source object to use for initiating a server shutdown

```yaml
Type: CancellationTokenSource
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
