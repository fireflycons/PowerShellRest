
<#
    Base class for stream compressors
#>
class CompressionBase
{
    <#
        Compress text to byte array
    #>
    [byte[]]Compress([string]$text)
    {
        $outputStream = $null
        $compressionStream = $null

        try
        {
            $outputStream = [System.IO.MemoryStream]::new()
            $compressionStream = $this.GetCompressionStream($outputStream)
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)

            $compressionStream.Write($bytes, 0, $bytes.Length)
        }
        finally
        {
            ($compressionStream, $outputStream) |
                Where-Object {
                $null -ne $_
            } |
                Foreach-Object {
                $_.Dispose()
            }
        }

        # https://blogs.msdn.microsoft.com/bclteam/2006/05/10/using-a-memorystream-with-gzipstream-lakshan-fernando/
        return $outputStream.ToArray()
    }

    <#
        Decompress byte array to text
    #>
    [string]Decompress([byte[]]$bytes)
    {
        $inputStream = $null
        $outputStream = $null
        $decompressionStream = $null

        try
        {
            $inputStream = [System.IO.MemoryStream]::new()
            $outputStream = [System.IO.MemoryStream]::new()
            $inputStream.Write($bytes, 0, $bytes.Length)
            $inputStream.Seek(0, [System.IO.SeekOrigin]::Begin)
            $decompressionStream = $this.GetDecompressionStream($inputStream)
            $decompressionStream.CopyTo($outputStream)
        }
        finally
        {
            ($decompressionStream, $inputStream, $outputStream) |
                Where-Object {
                $null -ne $_
            } |
                Foreach-Object {
                $_.Dispose()
            }
        }

        # https://blogs.msdn.microsoft.com/bclteam/2006/05/10/using-a-memorystream-with-gzipstream-lakshan-fernando/
        return [System.Text.Encoding]::UTF8.GetString($outputStream.ToArray())
    }

    [System.IO.Stream]GetCompressionStream([System.IO.Stream]$stream)
    {
        # All PowerShell class methods are virtual - subclass will be called
        return $null
    }

    [System.IO.Stream]GetDecompressionStream([System.IO.Stream]$stream)
    {
        # All PowerShell class methods are virtual - subclass will be called
        return $null
    }
}

<#
    GZip subclass
#>
class GZipCompression : CompressionBase
{
    GZipCompression()
    {
    }

    <#
        Retuurns a GZip compression stream wrapping the given stream
    #>
    [System.IO.Stream]GetCompressionStream([System.IO.Stream]$stream)
    {
        return [System.IO.Compression.GZipStream]::new($stream, [System.IO.Compression.CompressionMode]::Compress)
    }

    <#
        Retuurns a GZip decompression stream wrapping the given stream
    #>
    [System.IO.Stream]GetDecompressionStream([System.IO.Stream]$stream)
    {
        return [System.IO.Compression.GZipStream]::new($stream, [System.IO.Compression.CompressionMode]::Decompress)
    }
}

<#
    Deflate subclass
#>
class DeflateCompression : CompressionBase
{
    DeflateCompression()
    {
    }

    <#
        Retuurns a Deflate compression stream wrapping the given stream
    #>
    [System.IO.Stream]GetCompressionStream([System.IO.Stream]$stream)
    {
        return [System.IO.Compression.DeflateStream]::new($stream, [System.IO.Compression.CompressionMode]::Compress)
    }

    <#
        Retuurns a Deflate decompression stream wrapping the given stream
    #>
    [System.IO.Stream]GetDecompressionStream([System.IO.Stream]$stream)
    {
        return [System.IO.Compression.DeflateStream]::new($stream, [System.IO.Compression.CompressionMode]::Decompress)
    }
}

function New-Compressor
{
<#
    .SYNOPSIS
        Create a new compression class

    .DESCRIPTION
        Factory method to create compression classes from the algortihm name

    .PARAMETER Algorithm
        Alogirthm to use

    .OUTPUTS
        New compression class for requested type, or null if the type s not supported.
#>
    param
    (
        [string]$Algorithm
    )

    switch ($Algorithm)
    {
        'gzip'
        {
            [GZipCompression]::new()
        }

        'deflate'
        {
            [DeflateCompression]::new()
        }

        default
        {
            $null
        }
    }
}
