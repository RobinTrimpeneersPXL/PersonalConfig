# --- Profile: Fast PowerShell 7 Startup ---

# === CORE SETTINGS ===

# Ensure built-ins are available
$defaultModules = "$PSHOME\Modules"
if ($env:PSModulePath -notmatch [regex]::Escape($defaultModules)) {
    $env:PSModulePath = "$defaultModules;$env:PSModulePath"
}

# PowerShell behavior
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

# Cache directory setup
$cacheDir = "$env:USERPROFILE\.cache"
if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
}

# === PROMPT ===

# Starship prompt init (cached)
$starshipCache = "$cacheDir\starship_init.ps1"
if (-not (Test-Path $starshipCache)) {
    try { 
        starship init powershell | Out-File -Encoding utf8 $starshipCache 
    } catch {}
}
if (Test-Path $starshipCache) { . $starshipCache }

# === PSREADLINE ===

Import-Module PSReadLine -ErrorAction SilentlyContinue

# Basic options
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle InlineView
Set-PSReadLineOption -HistorySearchCaseSensitive:$false
Set-PSReadLineOption -HistoryNoDuplicates:$true
Set-PSReadLineOption -BellStyle None

# History filtering
Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $skip = @('^cd\s*$', '^ls\s*$', '^ll\s*$', '^cls\s*$', '^exit\s*$', 'password', 'secret', 'token')
    foreach ($pattern in $skip) {
        if ($line -match $pattern) { return $false }
    }
    return $true
}

# Colors
Set-PSReadLineOption -Colors @{
    InlinePrediction = "`e[38;5;242m"
    Command          = "`e[93m"
    Parameter        = "`e[94m"
}

# Key bindings
Set-PSReadLineKeyHandler -Key "Alt+s" -BriefDescription "Toggle Prediction View" -ScriptBlock {
    $current = (Get-PSReadLineOption).PredictionViewStyle
    $new = if ($current -eq 'InlineView') { 'ListView' } else { 'InlineView' }
    Set-PSReadLineOption -PredictionViewStyle $new
}
Set-PSReadLineKeyHandler -Key "Ctrl+RightArrow" -Function ForwardWord

# === MODULES ===

# Fast modules (load immediately)
Import-Module CompletionPredictor -ErrorAction SilentlyContinue

# Kubectl completion (cached)
$kubectlCache = "$cacheDir\kubectl_completion.ps1"
if (-not (Test-Path $kubectlCache)) {
    try { 
        kubectl completion powershell | Out-File -Encoding utf8 $kubectlCache 
    } catch {}
}
if (Test-Path $kubectlCache) { . $kubectlCache }

# Deferred module loading (only loads installed modules)
$deferredModules = @(
    'DockerCompletion',
    'posh-git',
    'Az.Tools.Predictor',
    'PSFzf',
    'Terminal-Icons'
)

$null = Register-EngineEvent PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    foreach ($module in $using:deferredModules) {
        if (Get-Module -ListAvailable $module) {
            Import-Module $module -ErrorAction SilentlyContinue
        }
    }
}

# === NAVIGATION ===

# Quick paths
$QuickPaths = @{
    home   = $env:USERPROFILE
    docs   = "$env:USERPROFILE\Documents"
    school = "D:\PXL\2025_2026"
    dl     = "$env:USERPROFILE\Downloads"
    desk   = "$env:USERPROFILE\Desktop"
}

function j {
    <#
    .SYNOPSIS
        Quick navigation to predefined locations
    .DESCRIPTION
        Jump to frequently used directories using short aliases
    .PARAMETER key
        Location alias (home, docs, proj, school, dl, desk). Leave empty to list all.
    .EXAMPLE
        j proj
        Navigates to your project directory
    .EXAMPLE
        j
        Lists all available locations
    #>
    param([string]$key)
    
    if ([string]::IsNullOrWhiteSpace($key)) {
        Write-Host "Available locations:" -ForegroundColor Cyan
        $QuickPaths.GetEnumerator() | Sort-Object Name | ForEach-Object {
            Write-Host "  $($_.Key.PadRight(8)) -> $($_.Value)" -ForegroundColor Gray
        }
        return
    }
    
    if ($QuickPaths.ContainsKey($key)) {
        $path = $QuickPaths[$key]
        if (Test-Path $path) {
            Set-Location $path
        } else {
            Write-Host "Path doesn't exist: $path" -ForegroundColor Red
        }
    } else {
        Write-Host "Unknown location: $key" -ForegroundColor Red
        Write-Host "Use 'j' without arguments to see available locations" -ForegroundColor Gray
    }
}

# Directory shortcuts
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }

function mkcd {
    <#
    .SYNOPSIS
        Create directory and navigate to it
    .DESCRIPTION
        Creates a new directory (including parent directories) and immediately changes to it
    .PARAMETER path
        Path of the directory to create
    .EXAMPLE
        mkcd C:\temp\newproject
        Creates the directory and navigates to it
    #>
    param([string]$path)
    if ([string]::IsNullOrWhiteSpace($path)) {
        Write-Host "Usage: mkcd <directory>" -ForegroundColor Yellow
        return
    }
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    Set-Location $path
}

# === FILE OPERATIONS ===

function ll {
    <#
    .SYNOPSIS
        Enhanced directory listing
    .DESCRIPTION
        Lists files and directories with formatted size and modification time
    .PARAMETER Path
        Path to list (default: current directory)
    .EXAMPLE
        ll
        Lists current directory
    .EXAMPLE
        ll C:\Windows
        Lists Windows directory
    #>
    param([string]$Path = ".")
    
    Get-ChildItem -Path $Path -Force | 
    Sort-Object @{Expression='PSIsContainer'; Descending=$true}, @{Expression='LastWriteTime'; Descending=$true} |
    Format-Table -AutoSize @(
        'Mode',
        @{Label='Size'; Expression={
            if ($_.PSIsContainer) { '<DIR>' }
            elseif ($_.Length -lt 1KB) { '{0} B' -f $_.Length }
            elseif ($_.Length -lt 1MB) { '{0:N2} KB' -f ($_.Length/1KB) }
            elseif ($_.Length -lt 1GB) { '{0:N2} MB' -f ($_.Length/1MB) }
            else { '{0:N2} GB' -f ($_.Length/1GB) }
        }; Align='Right'},
        @{Label='Modified'; Expression={$_.LastWriteTime.ToString('yyyy-MM-dd HH:mm')}},
        @{Label='Name'; Expression={
            if ($_.PSIsContainer) { $_.Name + '\' } else { $_.Name }
        }}
    )
}

function touch {
    param([string]$file)
    if ([string]::IsNullOrWhiteSpace($file)) {
        Write-Host "Usage: touch <filename>" -ForegroundColor Yellow
        return
    }
    if (Test-Path $file) {
        (Get-Item $file).LastWriteTime = Get-Date
    } else {
        New-Item -ItemType File -Path $file | Out-Null
    }
}

function which {
    param([string]$command)
    Get-Command $command -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
}

# === UTILITIES ===

# Encoding
function base64 {
    param([string]$text)
    [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($text))
}

function unbase64 {
    param([string]$encoded)
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
}

# Quick edits
function ep { code $PROFILE }
function eaws { code "$env:USERPROFILE\.aws\" }
function hosts { code "$env:SystemRoot\System32\drivers\etc\hosts" }

# AWS utilities
function aws-profile {
    <#
    .SYNOPSIS
        Show current AWS configuration
    .DESCRIPTION
        Displays active AWS profile, region, and account ID
    .EXAMPLE
        aws-profile
    #>
    $profile = if ($env:AWS_PROFILE) { $env:AWS_PROFILE } else { "default" }
    $region = if ($env:AWS_REGION) { $env:AWS_REGION } else { 
        try { aws configure get region 2>$null } catch { "not set" }
    }
    $account = try { 
        aws sts get-caller-identity --query Account --output text 2>$null 
    } catch { "not authenticated" }
    
    [PSCustomObject]@{
        Profile = $profile
        Region  = $region
        Account = $account
    } | Format-List
}

function clear-aws {
    <#
    .SYNOPSIS
        Clear AWS credentials and config
    .DESCRIPTION
        Removes AWS credentials and config files from ~/.aws/
    .EXAMPLE
        clear-aws
    #>
    $files = @(
        @{Path="$env:USERPROFILE\.aws\credentials"; Name="credentials"},
        @{Path="$env:USERPROFILE\.aws\config"; Name="config"}
    )
    
    foreach ($file in $files) {
        if (Test-Path $file.Path) {
            Remove-Item -Path $file.Path -Force
            Write-Host "AWS $($file.Name) removed." -ForegroundColor Green
        }
    }
    
    Write-Host "AWS config cleared! Run 'aws configure' to set up again." -ForegroundColor Cyan
}

# Network
function pingg { 
    Test-Connection google.com -Count 2 | 
    Format-Table Address, Status, @{L='Latency(ms)';E={$_.ResponseTime}} -AutoSize
}

function ports {
    Get-NetTCPConnection | Where-Object { $_.State -eq 'Listen' } |
    Select-Object LocalAddress, LocalPort, @{L='Process';E={(Get-Process -Id $_.OwningProcess).Name}} |
    Sort-Object LocalPort | Format-Table -AutoSize
}

function myip {
    [PSCustomObject]@{
        Local  = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike '*Loopback*' }).IPAddress -join ', '
        Public = (Invoke-RestMethod -Uri 'https://api.ipify.org?format=json').ip
    } | Format-List
}

# Docker
function clear-docker { 
    Write-Host "Cleaning Docker system..." -ForegroundColor Yellow
    docker system prune -af --volumes
    Write-Host "Docker cleanup complete!" -ForegroundColor Green
}

# Profile
function reload-profile { 
    . $PROFILE
    Write-Host "Profile reloaded!" -ForegroundColor Green
}




# initialize starship
Invoke-Expression (&starship init powershell)

# --- posh-git (git prompt & completion) ---
Import-Module posh-git

# --- PSReadLine config (autocomplete/prediction + nicer colors) ---
Import-Module PSReadLine
# Enable prediction from history
Set-PSReadLineOption -PredictionSource History
# show suggestions inline (like zsh autosuggestions)
Set-PSReadLineOption -PredictionViewStyle InlineView

# Improve keybindings 
Set-PSReadLineKeyHandler -Key Tab -Function Complete

