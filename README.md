# backup-tool

PowerShell-Skript zum sicheren Sichern und Wiederherstellen von **HCL/IBM Notes** und **Microsoft Edge** Daten.

**Repository:** https://github.com/gedankenstrom/backup-tool

## Features

- **Automatische Speicherort-Erkennung:** Netzwerk (HOMESHARE oder Registry) oder lokal
- **SHA256-Hash-Prüfung:** Jede Datei wird mit Hash gesichert und beim Restore verifiziert
- **Logging:** Alle Aktionen werden in `logs/backup.log` / `logs/restore.log` protokolliert
- **Selbstextrahierend:** Restore-Skripte werden automatisch mit kopiert/heruntergeladen

## Was wird gesichert?

### HCL/IBM Notes
- `bookmark.nsf` - Lesezeichen
- `Cache.NDK` - Cache
- `desktop8.ndk` - Desktop-Konfiguration

### Microsoft Edge
- `Bookmarks` - Favoriten (JSON-Format)
- `Bookmarks.bak` - Backup der Favoriten

## Schnellstart

### Kurze URL

```
https://bit.ly/bk-tool
```

### Backup erstellen

**Kurze URL:**
```powershell
irm https://bit.ly/bk-tool | iex
```

**Oder direkt von GitHub:**
```powershell
irm https://raw.githubusercontent.com/gedankenstrom/backup-tool/master/backup-tool.ps1 | iex
```

Oder herunterladen und ausführen:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gedankenstrom/backup-tool/master/backup-tool.ps1" -OutFile "$env:TEMP\backup-tool.ps1"
& "$env:TEMP\backup-tool.ps1"
```

**Ort:** `Dokumente\Notes_backup_YYYY-MM-DD\`

Das Script erkennt automatisch den optimalen Speicherort:
1. **Netzwerk (HOMESHARE):** Wenn `%HOMESHARE%` gesetzt ist und erreichbar
2. **Netzwerk (Registry):** Wenn in der Registry ein Netzwerk-Documents-Pfad hinterlegt ist (z. B. `\\server\users\...`)
3. **Lokal:** Sonst im lokalen Benutzerprofil unter `Dokumente\`

Beim Start wird angezeigt, welcher Modus aktiv ist (Netzwerk oder Lokal).

### Wiederherstellen

1. Im Backup-Ordner PowerShell öffnen
2. `restore.ps1` ausführen:
   ```powershell
   .\restore.ps1
   ```
   
   **Hinweis:** Falls eine Execution Policy Fehlermeldung erscheint, verwenden Sie:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File ".\restore.ps1"
   ```
3. **Notes und Edge werden automatisch beendet** (falls geöffnet)
4. Alle Dateien werden zurückkopiert
5. **Notes UND Edge neu starten**

### Nach dem Restore

- **Notes:** Starten Sie Notes neu, damit die Lesezeichen und Desktop-Einstellungen wirksam werden
- **Edge:** Starten Sie Edge neu, damit die Favoriten wiederhergestellt werden

## Dateien im Backup-Ordner

| Datei | Beschreibung |
|-------|--------------|
| `bookmark.nsf` | Notes Lesezeichen |
| `Cache.NDK` | Notes Cache |
| `desktop8.ndk` | Notes Desktop |
| `Bookmarks` | Edge Favoriten |
| `Bookmarks.bak` | Edge Favoriten Backup |
| `restore.ps1` | Wiederherstellung per PowerShell |
| `Wiederherstellen.txt` | Kurzanleitung |

### logs/ Unterordner

| Datei | Beschreibung |
|-------|--------------|
| `logs/backup.log` | Backup-Protokoll (mit Zeitstempel) |
| `logs/restore.log` | Restore-Protokoll |
| `logs/hashes.txt` | SHA256-Hashes aller Dateien |

## Logging & Verifikation

### Backup-Log (`logs/backup.log`)
Jedes Backup erstellt ein Protokoll mit:
- Zeitstempel, Benutzer, Computer
- Welche Dateien kopiert wurden
- SHA256-Hashes
- Fehler/Warnungen

### Hash-Verifikation beim Restore
`restore.ps1` vergleicht automatisch die SHA256-Hashes:
- **Grün:** Datei verifiziert (Hash stimmt)
- **Rot:** Verifikationsfehler (Datei möglicherweise korrupt)

## Anforderungen

- Windows 10/11
- PowerShell 5.1 oder höher
- HCL Notes, IBM Notes (optional)
- Microsoft Edge (optional)

## Fehlerbehebung

### Notes lässt sich nicht wiederherstellen
Notes muss vor dem Restore geschlossen sein. Das Skript versucht Notes automatisch zu beenden.

### Edge lässt sich nicht wiederherstellen
Edge muss vor dem Restore komplett geschlossen werden (alle Fenster!). Das Skript versucht dies automatisch.

### Änderungen erscheinen nicht
Nach dem Restore müssen **Notes UND Edge neu gestartet** werden, damit die Änderungen wirksam werden.

## Lizenz

MIT License
