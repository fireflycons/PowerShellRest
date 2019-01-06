---
external help file: PowerShellRest-help.xml
Module Name: PowerShellRest
online version:
schema: 2.0.0
---

# Start-RestServer

## SYNOPSIS
Starts the REST server

## SYNTAX

### MultiThreaded (Default)
```
Start-RestServer [-ClassPath <String[]>] [-BoundIp <String>] [-Port <UInt16>] [-LogFolder <String>]
 [-ThreadCount <Int32>] [-Service] [<CommonParameters>]
```

### SingleThreaded
```
Start-RestServer [-ClassPath <String[]>] [-BoundIp <String>] [-Port <UInt16>] [-LogFolder <String>]
 [-SingleThreaded] [-Service] [<CommonParameters>]
```

## DESCRIPTION
This is the main method for starting up a new server.

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -ClassPath
{{Fill ClassPath Description}}

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BoundIp
IP address to bind listener to.
Default 0.0.0.0 (all host interfaces)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 0.0.0.0
Accept pipeline input: False
Accept wildcard characters: False
```

### -Port
Port number to listen on.

```yaml
Type: UInt16
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogFolder
Root folder for logs.
Subdirectories 'HTTP' and 'Error' will be created within

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: ((Get-Location).Path)
Accept pipeline input: False
Accept wildcard characters: False
```

### -SingleThreaded
If set, start server in single threaded mode

```yaml
Type: SwitchParameter
Parameter Sets: SingleThreaded
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ThreadCount
Number of request processing threads to start.

```yaml
Type: Int32
Parameter Sets: MultiThreaded
Aliases:

Required: False
Position: Named
Default value: ([System.Environment]::ProcessorCount)
Accept pipeline input: False
Accept wildcard characters: False
```

### -Service
If set, run in service mode.
If not set, server will be single threaded and exit after processing the first request.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
