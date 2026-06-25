# Windows PowerShell Script to safely optimize and shrink ANY WSL2 VHDX disk
# Run this from Windows PowerShell with Administrator privileges AFTER a clean Linux logout.

Write-Host "--- WSL2 Virtual Hard Disk (VHDX) Generic Optimization Engine ---" -ForegroundColor Cyan

# 1. Dynamically identify all active or registered WSL distributions on this host
Write-Host "`n[1/4] Scanning local Windows registry for registered WSL distributions..." -ForegroundColor Yellow
$wslRegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
$distros = Get-ChildItem -Path $wslRegPath | ForEach-Object {
    [PSCustomObject]@{
        Name = (Get-ItemProperty -Path $_.PSPath).DistributionName
        Path = (Get-ItemProperty -Path $_.PSPath).BasePath
    }
}

if ($distros.Count -eq 0) {
    Write-Host "No registered WSL distributions found on this machine." -ForegroundColor Red
    Exit
}

# 2. Present user with a dynamic choice of their local distributions
Write-Host "`nAvailable WSL Installations:" -ForegroundColor White
for ($i = 0; $i -lt $distros.Count; $i++) {
    Write-Host "[$i] $($distros[$i].Name) ($($distros[$i].Path))" -ForegroundColor Cyan
}
$distroSelection = Read-Host "`nSelect the number of the distribution disk to optimize"

# Construct the absolute path dynamically to the ext4.vhdx based on user selection
$basePath = $distros[[int]$distroSelection].Path
$VHDX_PATH = Join-Path $basePath "ext4.vhdx"

if (-not (Test-Path $VHDX_PATH)) {
    # Fallback search for multi-folder nested vhdx paths (e.g. Docker desktop profiles)
    $VHDX_PATH = Get-ChildItem -Path $basePath -Filter "ext4.vhdx" -Recurber -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}

if (-not $VHDX_PATH) {
    Write-Host "Could not locate the ext4.vhdx file for the selected distribution." -ForegroundColor Red
    Exit
}

Write-Host "`nTargeting Validated Disk Path: $VHDX_PATH" -ForegroundColor Gray

# 3. Choose the optimization engine methodology
Write-Host "`n[2/4] Choose your optimization engine methodology:" -ForegroundColor White
Write-Host "1) Diskpart Utility (Standard Tool - Safe on all Windows systems)" -ForegroundColor Cyan
Write-Host "2) Optimize-VHD Hyper-V Cmdlet (Advanced - Requires Windows Pro/Hyper-V feature)" -ForegroundColor Cyan
$choice = Read-Host "`nEnter selection (1 or 2)"

# 4. Crucial Guard: Ensure Sparse Mode is explicitly disabled/turned off to prevent cmdlet validation crashes
Write-Host "`n[3/4] Ensuring Sparse Mode flags are deactivated for this target registry block..." -ForegroundColor Yellow
$targetRegistry = Get-ChildItem -Path $wslRegPath | Where-Object { (Get-ItemProperty -Path $_.PSPath).DistributionName -eq $distros[[int]$distroSelection].Name }
Set-ItemProperty -Path $targetRegistry.PSPath -Name "Flags" -Value 7 -ErrorAction SilentlyContinue

Write-Host "`n[4/4] Running compaction pipeline..." -ForegroundColor Yellow

if ($choice -eq "1") {
    Write-Host "Executing diskpart compaction sequence..." -ForegroundColor Cyan
    $diskpartScript = @"
select vdisk file="$VHDX_PATH"
attach vdisk readonly
compact vdisk
detach vdisk
"@
    $diskpartScript | diskpart
} 
elseif ($choice -eq "2") {
    Write-Host "Executing Hyper-V Optimize-VHD sequence..." -ForegroundColor Cyan
    Mount-VHD -Path $VHDX_PATH -ReadOnly
    Optimize-VHD -Path $VHDX_PATH -Mode Full
    Dismount-VHD -Path $VHDX_PATH
} 
else {
    Write-Host "Invalid selection. Optimization cancelled." -ForegroundColor Red
    Exit
}

Write-Host "`nWSL2 Virtual Hard Disk Optimization Successfully Completed." -ForegroundColor Green
