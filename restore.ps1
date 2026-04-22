# backup-tool - Restore Script
# PowerShell-Skript zum Wiederherstellen von
# HCL/IBM Notes und Microsoft Edge Daten

$host.ui.RawUI.WindowTitle = "Notes & Edge Restore"

$BackupPfad = Split-Path -Parent $MyInvocation.MyCommand.Path
$Datum = Get-Date -Format "yyyy-MM-dd HH:mm"

# Logs-Ordner erstellen und Log-Datei initialisieren
$LogsOrdner = Join-Path $BackupPfad "logs"
if (!(Test-Path -Path $LogsOrdner)) {
    New-Item -ItemType Directory -Path $LogsOrdner -Force | Out-Null
}
$LogFile = Join-Path $LogsOrdner "restore.log"
$HashFile = Join-Path $LogsOrdner "hashes.txt"

$Wiederhergestellt = 0
$VerifikationErfolg = 0
$VerifikationFehler = 0

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
    if ($LogFile) {
        try {
            # Sicherstellen, dass das Verzeichnis existiert
            $logDir = Split-Path -Parent $LogFile
            if (!(Test-Path -Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            # Bei UNC-Pfaden: Neue Zeile mit Out-File -Append verwenden (zuverlässiger)
            $logEntry | Out-File -FilePath $LogFile -Append -Encoding UTF8 -ErrorAction Stop
        }
        catch {
            Write-Host "[LOG-FEHLER] Konnte nicht in Log-Datei schreiben: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Log-Datei Header
Write-Log "========================================" "INFO"
Write-Log "Restore gestartet: $Datum" "INFO"
Write-Log "Backup-Ordner: $BackupPfad" "INFO"
Write-Log "Benutzer: $($env:USERNAME)" "INFO"
Write-Log "Computer: $($env:COMPUTERNAME)" "INFO"
Write-Log "========================================" "INFO"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Notes & Edge - Restore" -ForegroundColor Cyan
Write-Host "  Backup: $BackupPfad" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# === LOTUS NOTES BEENDEN ===
Write-Host "--- Notes vorbereiten ---" -ForegroundColor Cyan
Write-Host ""
Write-Log "Notes vorbereiten" "INFO"

$NotesProzesse = Get-Process notes -ErrorAction SilentlyContinue
if ($NotesProzesse) {
    Write-Host "Beende Notes..." -ForegroundColor Yellow
    Stop-Process -Name notes -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Write-Log "Notes beendet" "OK"
} else {
    Write-Log "Notes war nicht gestartet" "OK"
}

Write-Host ""

# === MICROSOFT EDGE BEENDEN ===
Write-Host "--- Edge vorbereiten ---" -ForegroundColor Cyan
Write-Host ""
Write-Log "Edge vorbereiten" "INFO"

$EdgeProzesse = Get-Process msedge -ErrorAction SilentlyContinue
if ($EdgeProzesse) {
    Write-Host "Beende Edge..." -ForegroundColor Yellow
    Stop-Process -Name msedge -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Write-Log "Edge beendet" "OK"
} else {
    Write-Log "Edge war nicht gestartet" "OK"
}

Write-Host ""

# Zielordner
$NotesZiel = "$env:LOCALAPPDATA\HCL\Notes\Data"
if (!(Test-Path -Path $NotesZiel)) {
    $NotesZiel = "$env:LOCALAPPDATA\IBM\Notes\Data"
}
$EdgeZiel = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"

Write-Log "Notes-Ziel: $NotesZiel" "INFO"
Write-Log "Edge-Ziel: $EdgeZiel" "INFO"

# === LOTUS NOTES ===
Write-Host "--- HCL/IBM Notes ---" -ForegroundColor Cyan
Write-Host ""
Write-Log "Notes Restore gestartet" "INFO"

if (Test-Path -Path $NotesZiel) {
    foreach ($Datei in @("bookmark.nsf", "Cache.NDK", "desktop8.ndk")) {
        $BackupDatei = Join-Path $BackupPfad $Datei
        $ZielDatei = Join-Path $NotesZiel $Datei
        
        if (Test-Path $BackupDatei) {
            try {
                Copy-Item $BackupDatei $ZielDatei -Force
                $Groesse = (Get-Item $ZielDatei).Length
                Write-Log "Notes: $Datei wiederhergestellt ($Groesse Bytes)" "OK"
                $Wiederhergestellt++
            }
            catch {
                Write-Log "Notes: $Datei - Fehler: $($_.Exception.Message)" "ERR"
            }
        }
        else {
            Write-Log "Notes: $Datei nicht im Backup gefunden" "WARN"
        }
    }
} else {
    Write-Log "Notes-Zielordner nicht gefunden: $NotesZiel" "WARN"
}

# === MICROSOFT EDGE ===
Write-Host ""
Write-Host "--- Microsoft Edge ---" -ForegroundColor Cyan
Write-Host ""
Write-Log "Edge Restore gestartet" "INFO"

if (Test-Path $EdgeZiel) {
    foreach ($Datei in @("Bookmarks", "Bookmarks.bak")) {
        $BackupDatei = Join-Path $BackupPfad $Datei
        $ZielDatei = Join-Path $EdgeZiel $Datei
        
        if (Test-Path $BackupDatei) {
            try {
                Copy-Item $BackupDatei $ZielDatei -Force
                $Groesse = (Get-Item $ZielDatei).Length
                Write-Log "Edge: $Datei wiederhergestellt ($Groesse Bytes)" "OK"
                $Wiederhergestellt++
            }
            catch {
                Write-Log "Edge: $Datei - Fehler: $($_.Exception.Message)" "ERR"
            }
        }
        else {
            Write-Log "Edge: $Datei nicht im Backup gefunden" "WARN"
        }
    }
} else {
    Write-Log "Edge-Zielordner nicht gefunden: $EdgeZiel" "WARN"
}

# === HASH-VERIFIKATION ===
Write-Host ""
Write-Host "--- Hash-Verifikation ---" -ForegroundColor Cyan
Write-Host ""
Write-Log "Hash-Verifikation gestartet" "INFO"

if (Test-Path $HashFile) {
    $Hashes = Get-Content $HashFile
    Write-Log "Hash-Datei gefunden: $HashFile" "OK"
    
    foreach ($Zeile in $Hashes) {
        $Teile = $Zeile -split "\t"
        if ($Teile.Count -ge 2) {
            $DateiName = $Teile[0]
            $ErwarteterHash = $Teile[1]
            $DateiPfad = Join-Path $BackupPfad $DateiName
            
            if (Test-Path $DateiPfad) {
                $AktuellerHash = Get-FileHashSHA256 $DateiPfad
                if ($AktuellerHash -eq $ErwarteterHash) {
                    Write-Log "Verifikation OK: $DateiName" "OK"
                    $VerifikationErfolg++
                }
                else {
                    Write-Log "Verifikation FEHLER: $DateiName (Hash stimmt nicht überein!)" "ERR"
                    $VerifikationFehler++
                }
            }
            else {
                Write-Log "Verifikation SKIP: $DateiName (nicht im Backup)" "WARN"
            }
        }
    }
    
    Write-Host ""
    if ($VerifikationFehler -eq 0) {
        Write-Host "[OK] Alle Hashes verifiziert ($VerifikationErfolg Dateien)" -ForegroundColor Green
    }
    else {
        Write-Host "[WARN] $VerifikationFehler Datei(en) mit Hash-Fehler!" -ForegroundColor Yellow
    }
}
else {
    Write-Log "Keine Hash-Datei gefunden ($HashFile) - Verifikation übersprungen" "WARN"
    Write-Host "[INFO] Keine Hash-Datei gefunden - Verifikation übersprungen" -ForegroundColor Yellow
}

# Zusammenfassung
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Restore abgeschlossen!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Wiederhergestellt: $Wiederhergestellt Dateien" -ForegroundColor White
if ($VerifikationErfolg -gt 0) {
    Write-Host "Verifiziert: $VerifikationErfolg Dateien" -ForegroundColor Green
}
if ($VerifikationFehler -gt 0) {
    Write-Host "Verifikationsfehler: $VerifikationFehler" -ForegroundColor Red
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Starten Sie Notes UND Edge neu!" -ForegroundColor Yellow
Write-Host ""

# Zusammenfassung loggen
Write-Log "========================================" "INFO"
Write-Log "Restore abgeschlossen" "INFO"
Write-Log "Wiederhergestellt: $Wiederhergestellt Dateien" "INFO"
Write-Log "Verifiziert: $VerifikationErfolg | Fehler: $VerifikationFehler" "INFO"
Write-Log "Log-Ordner: $LogsOrdner" "INFO"
Write-Log "========================================" "INFO"

Write-Host "Log: $LogsOrdner\restore.log" -ForegroundColor Gray
Write-Host "Hashes: $LogsOrdner\hashes.txt" -ForegroundColor Gray
Write-Host ""

Write-Host "Fenster kann jetzt geschlossen werden." -ForegroundColor White
Start-Sleep -Seconds 2
