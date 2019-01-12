enum EventId
{
    # Info messages < 0x10
    ServerStarted = 1
    ServerStopped = 2
    InitializationStep = 3
    ThreadWarm = 4
    ControllerLoad = 5
    DebugEvent = 0x0f

    # Warning messages 0x10 - 0x1f
    RouteHandlingException = 0x10

    # Error messages 0x20-0x2f
    Exception = 0x20
    Fatal = 0x2f
}
