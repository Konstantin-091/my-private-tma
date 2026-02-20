<# :
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content '%~f0') -join [Environment]::NewLine)"
pause
exit /b
#>

# --- CLEAN POWERSHELL CODE (ENGLISH CONSOLE) ---
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Drawing

Write-Host "--- IMAGE PROCESSOR V2 + 9:16 MAGIC ---" -ForegroundColor Cyan
$StartInput = Read-Host "Enter starting number (e.g. 31)"

# Force convert to integer
try {
    [int]$curr = [int]$StartInput
} catch {
    Write-Host "ERROR: Please enter a valid number!" -ForegroundColor Red
    return
}

$folder = Get-Location
$extensions = @('.jpg', '.jpeg', '.png', '.webp', '.bmp', '.jfif')

# Target Resolution for Mobile 9:16
$CanvasW = 720
$CanvasH = 1280

# Find files that are NOT named as plain numbers
$files = Get-ChildItem -Path $folder.Path -File | Where-Object { 
    $extensions -contains $_.Extension.ToLower() -and $_.BaseName -notmatch '^\d+$' 
}

if ($files.Count -eq 0) {
    Write-Host "No new files found in: $($folder.Path)" -ForegroundColor Yellow
    return
}

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageDecoders() | Where-Object { $_.FormatID -eq [System.Drawing.Imaging.ImageFormat]::Jpeg.Guid }
$ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 60L)

foreach ($f in $files) {
    # Check if target filename already exists
    $newName = "$curr.jpg"
    $newP = Join-Path $folder.Path $newName
    
    while (Test-Path $newP) {
        $curr++
        $newName = "$curr.jpg"
        $newP = Join-Path $folder.Path $newName
    }

    Write-Host "Processing: $($f.Name) -> $newName" -ForegroundColor White
    try {
        # Using Stream for NVMe efficiency
        $stream = New-Object System.IO.FileStream($f.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
        $oldImg = [System.Drawing.Image]::FromStream($stream)
        $stream.Close(); $stream.Dispose()

        # STEP 1: Create Black 9:16 Canvas
        $canvas = New-Object System.Drawing.Bitmap($CanvasW, $CanvasH)
        $g = [System.Drawing.Graphics]::FromImage($canvas)
        $g.Clear([System.Drawing.Color]::Black)

        # STEP 2: Calculate Proportions (Fit without stretching)
        $ratioW = $CanvasW / $oldImg.Width
        $ratioH = $CanvasH / $oldImg.Height
        $ratio = [Math]::Min($ratioW, $ratioH)
        
        $finalW = [int]($oldImg.Width * $ratio)
        $finalH = [int]($oldImg.Height * $ratio)
        
        # STEP 3: Center the image on canvas
        $posX = [int](($CanvasW - $finalW) / 2)
        $posY = [int](($CanvasH - $finalH) / 2)

        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($oldImg, $posX, $posY, $finalW, $finalH)
        
        # STEP 4: Save with 60% quality
        $canvas.Save($newP, $jpegCodec, $ep)
        
        # Proper cleanup for 32GB RAM efficiency
        $g.Dispose()
        $canvas.Dispose()
        $oldImg.Dispose()
        
        # Remove original file
        Remove-Item $f.FullName -Force
        
        Write-Host "  [SUCCESS: 9:16 FIT]" -ForegroundColor Green
        $curr++
    } catch {
        Write-Host "  [FAILED] Skipping: $($f.Name). Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nFINISHED! Your images are ready for Private Storage." -ForegroundColor Magenta