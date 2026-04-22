# backup-tool
# PowerShell-Skript zum sicheren Sichern und Wiederherstellen
# von HCL/IBM Notes und Microsoft Edge Daten

param(
    [string]$CustomPath = ""
)

$Datum = Get-Date -Format "yyyy-MM-dd"
$Zeitstempel = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$Benutzer = $env:USERNAME
$Computer = $env:COMPUTERNAME

# Funktion: Registry nach Netzwerk-Documents durchsuchen
function Get-HomeDirectoryFromRegistry {
    try {
        $regPaths = @(
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"
        )
        foreach ($regPath in $regPaths) {
            if (Test-Path $regPath) {
                $regValue = Get-ItemProperty -Path $regPath -Name "Personal" -ErrorAction SilentlyContinue
                if ($regValue.Personal -like '\\*') {
                    $uncRoot = Split-Path $regValue.Personal -Parent
                    if (Test-Path $uncRoot) {
                        return $uncRoot
                    }
                }
            }
        }
    }
    catch { }
    return $null
}

# Funktion: SHA256-Hash berechnen
function Get-FileHashSHA256 {
    param([string]$FilePath)
    try {
        $hash = Get-FileHash -Path $FilePath -Algorithm SHA256 -ErrorAction Stop
        return $hash.Hash
    }
    catch {
        return "ERROR"
    }
}

# Funktion: Logging
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $logEntry = "[$Level] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Write-Host $logEntry
    if ($script:LogFile) {
        try {
            # Sicherstellen, dass das Verzeichnis existiert
            $logDir = Split-Path -Parent $script:LogFile
            if (!(Test-Path -Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            # Bei UNC-Pfaden: Neue Zeile mit Out-File -Append verwenden (zuverlässiger)
            $logEntry | Out-File -FilePath $script:LogFile -Append -Encoding UTF8 -ErrorAction Stop
        }
        catch {
            Write-Host "[LOG-FEHLER] Konnte nicht in Log-Datei schreiben: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Zielordner
if ($CustomPath -ne "") {
    $Ziel = $CustomPath
    $BackupModus = "Custom"
}
elseif ($env:HOMESHARE -and (Test-Path "$env:HOMESHARE\Documents")) {
    $Ziel = "$env:HOMESHARE\Documents\Notes_backup_$Datum"
    $BackupModus = "Netzwerk (HOMESHARE)"
}
else {
    $RegistryHome = Get-HomeDirectoryFromRegistry
    if ($RegistryHome -and (Test-Path "$RegistryHome\Documents")) {
        $env:HOMESHARE = $RegistryHome
        $Ziel = "$env:HOMESHARE\Documents\Notes_backup_$Datum"
        $BackupModus = "Netzwerk (Registry)"
    }
    else {
        $Ziel = "$env:USERPROFILE\Documents\Notes_backup_$Datum"
        $BackupModus = "Lokal"
    }
}

# Logs-Ordner erstellen und Log-Datei initialisieren
$LogsOrdner = Join-Path $Ziel "logs"
if (!(Test-Path -Path $LogsOrdner)) {
    New-Item -ItemType Directory -Path $LogsOrdner -Force | Out-Null
}
$script:LogFile = Join-Path $LogsOrdner "backup.log"
$HashFile = Join-Path $LogsOrdner "hashes.txt"

$Erfolg = 0
$Fehler = 0
$NichtGefunden = 0
$BackupHashes = @()

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  HCL/IBM Notes & Edge Backup" -ForegroundColor Cyan
Write-Host "  Datum: $Datum" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Zielverzeichnis erstellen
if (!(Test-Path -Path $Ziel)) {
    try {
        New-Item -ItemType Directory -Path $Ziel -Force | Out-Null
        Write-Log "Backup-Ordner erstellt: $Ziel" "OK"
    }
    catch {
        Write-Log "Konnte Zielordner nicht erstellen: $($_.Exception.Message)" "ERR"
        exit 1
    }
}
else {
    Write-Log "Backup-Ordner existiert bereits: $Ziel" "INFO"
}

# Log-Datei Header
Write-Log "========================================" "INFO"
Write-Log "Backup gestartet: $Zeitstempel" "INFO"
Write-Log "Benutzer: $Benutzer" "INFO"
Write-Log "Computer: $Computer" "INFO"
Write-Log "Backup-Modus: $BackupModus" "INFO"
Write-Log "Ziel: $Ziel" "INFO"
Write-Log "========================================" "INFO"

Write-Host ""
Write-Host "--- HCL/IBM Notes ---" -ForegroundColor Cyan
Write-Host ""
Write-Log "HCL/IBM Notes Backup gestartet" "INFO"

# Notes Quellordner ermitteln
$NotesQuelle = "$env:LOCALAPPDATA\HCL\Notes\Data"
if (!(Test-Path -Path $NotesQuelle)) {
    $NotesQuelle = "$env:LOCALAPPDATA\IBM\Notes\Data"
}

# Notes Dateien
$NotesDateien = @(
    "bookmark.nsf",
    "Cache.NDK",
    "desktop8.ndk"
)

if (Test-Path -Path $NotesQuelle) {
    foreach ($Datei in $NotesDateien) {
        $QuellPfad = Join-Path -Path $NotesQuelle -ChildPath $Datei
        if (Test-Path -Path $QuellPfad) {
            try {
                $DateiInfo = Get-Item -Path $QuellPfad
                $DateiGroesse = $DateiInfo.Length / 1MB
                Copy-Item -Path $QuellPfad -Destination $Ziel -Force
                
                # Hash berechnen
                $ZielPfad = Join-Path $Ziel $Datei
                $Hash = Get-FileHashSHA256 $ZielPfad
                $BackupHashes += "$Datei`t$Hash`t$($DateiInfo.Length)"
                
                Write-Log "Notes: $Datei kopiert ($($DateiGroesse:N2) MB, Hash: $Hash)" "OK"
                $Erfolg++
            }
            catch {
                Write-Log "Notes: $Datei - Fehler: $($_.Exception.Message)" "ERR"
                $Fehler++
            }
        }
        else {
            Write-Log "Notes: $Datei nicht gefunden" "WARN"
            $NichtGefunden++
        }
    }
}
else {
    Write-Log "HCL/IBM Notes nicht gefunden - wird übersprungen" "WARN"
    $NichtGefunden += 3
}

Write-Host ""
Write-Host "--- Microsoft Edge Favoriten ---" -ForegroundColor Cyan
Write-Host ""
Write-Log "Edge Favoriten Backup gestartet" "INFO"

# Edge Favoriten Pfade
$EdgePfade = @(
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Bookmarks",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Bookmarks.bak"
)

$EdgeGefunden = $false
foreach ($EdgePfad in $EdgePfade) {
    if (Test-Path -Path $EdgePfad) {
        try {
            $DateiInfo = Get-Item -Path $EdgePfad
            $DateiGroesse = $DateiInfo.Length / 1KB
            $DateiName = Split-Path -Leaf $EdgePfad
            Copy-Item -Path $EdgePfad -Destination $Ziel -Force
            
            # Hash berechnen
            $ZielPfad = Join-Path $Ziel $DateiName
            $Hash = Get-FileHashSHA256 $ZielPfad
            $BackupHashes += "$DateiName`t$Hash`t$($DateiInfo.Length)"
            
            Write-Log "Edge: $DateiName kopiert ($($DateiGroesse:N2) KB, Hash: $Hash)" "OK"
            $EdgeGefunden = $true
            $Erfolg++
        }
        catch {
            Write-Log "Edge: Konnte $DateiName nicht kopieren: $($_.Exception.Message)" "ERR"
            $Fehler++
        }
    }
}

if (!$EdgeGefunden) {
    Write-Log "Edge Favoriten nicht gefunden" "WARN"
    $NichtGefunden++
}

# Hashes in Datei schreiben
if ($BackupHashes.Count -gt 0) {
    $BackupHashes | Out-File -FilePath $HashFile -Encoding UTF8 -Force
    Write-Log "Hashes gespeichert in: $HashFile" "OK"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Backup abgeschlossen!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Ort: $Ziel" -ForegroundColor White
Write-Host ""
Write-Host ("Erfolgreich: {0} | Fehler: {1} | Nicht gefunden: {2}" -f $Erfolg, $Fehler, $NichtGefunden)
Write-Host ""

# Restore-Skripte ins Backup kopieren
Write-Host ""
Write-Host "--- Restore-Skripte ---" -ForegroundColor Cyan
Write-Host ""

$RestorePsd1 = Join-Path -Path $Ziel -ChildPath "restore.ps1"
$WiederherstellenTxt = Join-Path -Path $Ziel -ChildPath "Wiederherstellen.txt"
$RestoreErfolg = $false
$WiederherstellenErfolg = $false

try {
    $ScriptPfad = Split-Path -Parent $MyInvocation.MyCommand.Path
    if ($ScriptPfad -and ($ScriptPfad -ne "")) {
        $LokalesPs1 = Join-Path -Path $ScriptPfad -ChildPath "restore.ps1"
        $LokalesWiederherstellen = Join-Path -Path $ScriptPfad -ChildPath "Wiederherstellen.txt"
        
        if (Test-Path -Path $LokalesPs1) {
            Copy-Item -Path $LokalesPs1 -Destination $RestorePsd1 -Force
            Write-Log "restore.ps1 kopiert" "OK"
            $RestoreErfolg = $true
        }
        
        if (Test-Path -Path $LokalesWiederherstellen) {
            Copy-Item -Path $LokalesWiederherstellen -Destination $WiederherstellenTxt -Force
            Write-Log "Wiederherstellen.txt kopiert" "OK"
            $WiederherstellenErfolg = $true
        }
    }
}
catch {
    # Ignorieren - wird per Download geladen
}

if (!$RestoreErfolg) {
    $RestoreUrl = "https://raw.githubusercontent.com/gedankenstrom/backup-tool/master/restore.ps1"
    try {
        Invoke-WebRequest -Uri $RestoreUrl -OutFile $RestorePsd1 -UseBasicParsing
        Write-Log "restore.ps1 heruntergeladen" "OK"
        $RestoreErfolg = $true
    }
    catch {
        Write-Log "Konnte restore.ps1 nicht erstellen" "ERR"
    }
}

if (!$WiederherstellenErfolg) {
    $WiederherstellenUrl = "https://raw.githubusercontent.com/gedankenstrom/backup-tool/master/Wiederherstellen.txt"
    try {
        Invoke-WebRequest -Uri $WiederherstellenUrl -OutFile $WiederherstellenTxt -UseBasicParsing
        Write-Log "Wiederherstellen.txt heruntergeladen" "OK"
        $WiederherstellenErfolg = $true
    }
    catch {
        Write-Log "Wiederherstellen.txt nicht verfuegbar" "WARN"
    }
}

if ($RestoreErfolg) {
    Write-Host ""
    Write-Host "Restore per PowerShell: restore.ps1" -ForegroundColor Green
}

# Zusammenfassung loggen
Write-Log "========================================" "INFO"
Write-Log "Backup abgeschlossen" "INFO"
Write-Log "Erfolgreich: $Erfolg | Fehler: $Fehler | Nicht gefunden: $NichtGefunden" "INFO"
Write-Log "Backup-Ordner: $Ziel" "INFO"
Write-Log "Log-Ordner: $LogsOrdner" "INFO"
Write-Log "Hash-Datei: $HashFile" "INFO"
Write-Log "========================================" "INFO"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Backup abgeschlossen!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Ort: $Ziel" -ForegroundColor White
Write-Host "Log: $LogsOrdner\backup.log" -ForegroundColor Gray
Write-Host "Hashes: $LogsOrdner\hashes.txt" -ForegroundColor Gray
Write-Host ""
Write-Host ("Erfolgreich: {0} | Fehler: {1} | Nicht gefunden: {2}" -f $Erfolg, $Fehler, $NichtGefunden)
Write-Host ""

# Explorer öffnen
$Antwort = Read-Host "Explorer öffnen? (J/N)"
if ($Antwort -eq "J" -or $Antwort -eq "j") {
    Start-Process explorer.exe -ArgumentList $Ziel
}

exit 0
