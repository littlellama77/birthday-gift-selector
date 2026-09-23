# Pure ASCII PowerShell Static Server
$port = 3000
$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $baseDir) { $baseDir = Get-Location }

function Test-PortAvailable([int]$checkPort) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $checkPort)
        $tcp.Start()
        $tcp.Stop()
        return $true
    } catch {
        return $false
    }
}

while (-not (Test-PortAvailable $port) -and $port -lt 3010) {
    $port++
}

$url = "http://localhost:$port/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)

try {
    $listener.Start()
    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Green
    Write-Host "  Birthday Gift Processing Portal is running at:" -ForegroundColor Cyan
    Write-Host "  $url" -ForegroundColor Yellow
    Write-Host "===========================================================" -ForegroundColor Green
    Write-Host "  Opening default browser automatically..." -ForegroundColor Gray
    Write-Host "  Press Ctrl+C to terminate the server." -ForegroundColor Gray
    Write-Host ""
    
    Start-Process $url
} catch {
    Write-Error "Failed to start HttpListener: $_"
    exit 1
}

$mimeTypes = @{
    '.html' = 'text/html; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.jsx'  = 'text/plain; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.svg'  = 'image/svg+xml'
    '.ico'  = 'image/x-icon'
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $path = $request.Url.LocalPath.TrimStart('/')
        if ([string]::IsNullOrEmpty($path) -or $path -eq '/') {
            $path = 'index.html'
        }

        $filePath = Join-Path $baseDir $path

        if (Test-Path $filePath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            $contentType = 'application/octet-stream'
            if ($mimeTypes.ContainsKey($ext)) {
                $contentType = $mimeTypes[$ext]
            }
            $response.ContentType = $contentType
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.StatusCode = 200
        } else {
            $response.StatusCode = 404
            $msg = [System.Text.Encoding]::UTF8.GetBytes('404 Not Found')
            $response.OutputStream.Write($msg, 0, $msg.Length)
        }
        $response.Close()
    }
} finally {
    $listener.Stop()
    $listener.Close()
}
