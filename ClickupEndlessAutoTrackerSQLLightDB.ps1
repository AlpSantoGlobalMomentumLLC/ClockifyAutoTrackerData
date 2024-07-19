# Clickup Auto Tracker Sync. for an endless tracking
# Path: C:\Users\Axel_desktop\AppData\Local\Clockify\ClockifyDB_ACL.db
# Open with an SQLLight viewer

[CmdletBinding()]
param()

# Funktion zum Ändern der Execution Policy
function Set-ExecutionPolicySafely {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("RemoteSigned", "AllSigned", "Bypass", "Unrestricted")]
        [string]$Policy
    )
    
    try {
        Set-ExecutionPolicy -ExecutionPolicy $Policy -Scope Process -Force -ErrorAction Stop
        Write-Verbose "Execution Policy erfolgreich auf $Policy gesetzt."
    } catch {
        Write-Warning "Fehler beim Setzen der Execution Policy: $_"
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
            Write-Warning "Versuche, als Administrator auszuführen..."
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
            exit
        }
    }
}

# Hauptfunktion
function Sync-ClockifyDB {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        [Parameter(Mandatory=$true)]
        [string]$DestPath
    )

    process {
        Set-ExecutionPolicySafely -Policy RemoteSigned

        if (-not (Get-Module -ListAvailable -Name PSSQLite)) {
            Write-Verbose "PSSQLite-Modul wird installiert..."
            Install-Module -Name PSSQLite -Force -Scope CurrentUser -ErrorAction Stop
        }

        Import-Module PSSQLite -ErrorAction Stop

        if (-not (Test-Path $SourcePath)) {
            throw "Die Quelldatenbank wurde nicht gefunden: $SourcePath"
        }

        if (-not (Test-Path $DestPath)) {
            Write-Verbose "Zieldatenbank nicht gefunden. Erstelle neue Datenbank..."
            $createTableQuery = Invoke-SqliteQuery -DataSource $SourcePath -Query "SELECT sql FROM sqlite_master WHERE type='table' AND name='AutoTrackerItems'" | Select-Object -ExpandProperty sql
            Invoke-SqliteQuery -DataSource $DestPath -Query $createTableQuery
            Write-Verbose "Zieldatenbank wurde erfolgreich erstellt."
        }

        $query = @"
        ATTACH DATABASE '$DestPath' AS dest;
        INSERT INTO dest.AutoTrackerItems
        SELECT s.*
        FROM AutoTrackerItems s
        LEFT JOIN dest.AutoTrackerItems d
        ON s.Id = d.Id AND s.StartTime = d.StartTime AND s.EndTime = d.EndTime
        WHERE d.Id IS NULL;
        DETACH DATABASE dest;
"@

        Invoke-SqliteQuery -DataSource $SourcePath -Query $query -ErrorAction Stop
        Write-Output "Neue Einträge wurden erfolgreich kopiert."
    }
}

# Hauptausführung
try {
    $VerbosePreference = "Continue"
    $sourcePath = "C:\Users\Axel_desktop\AppData\Local\Clockify\ClockifyDB.db"
    $destPath = "C:\Users\Axel_desktop\AppData\Local\Clockify\ClockifyDB_ACL.db"
    
    Sync-ClockifyDB -SourcePath $sourcePath -DestPath $destPath
} catch {
    Write-Error "Ein Fehler ist aufgetreten: $_"
} finally {
    Write-Host "Drücken Sie Enter, um fortzufahren..."
    $null = Read-Host
}
