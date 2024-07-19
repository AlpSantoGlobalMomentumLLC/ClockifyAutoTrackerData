# Clickup Auto Tracker Sync. for an endless tracking and CSV Export
# CHANGE PATH!!! In the script: C:\Users\Axel_desktop\AppData\Local\Clockify\
# Open with an SQLLight viewer


[CmdletBinding()]
param(
    [string]$SourceDBPath = "C:\Users\Axel_desktop\AppData\Local\Clockify\ClockifyDB.db",
    [string]$DestCSVPath = "C:\Users\Axel_desktop\AppData\Local\Clockify\ClockifyDB_ACL.csv"
)

function Get-SQLiteTableStructure {
    param([string]$DBPath, [string]$TableName)
    Import-Module PSSQLite -ErrorAction Stop
    Invoke-SqliteQuery -DataSource $DBPath -Query "PRAGMA table_info($TableName);" | 
        Where-Object name -ne 'Icon' | 
        Select-Object -ExpandProperty name
}

function Format-CSVField {
    param([string]$Field)
    if ($Field -match '[;"\r\n]') {
        return '"' + ($Field -replace '"', '""') + '"'
    }
    return $Field
}

function Sync-ClockifyCSV {
    param([string]$SourceDBPath, [string]$DestCSVPath)
    
    $allColumns = Get-SQLiteTableStructure -DBPath $SourceDBPath -TableName "AutoTrackerItems"
    $orderedColumns = @('Name', 'StartTime', 'EndTime', 'Description', 'TotalTime', 'Id', 'IdleSeconds', 'IsEntryCreated', 'Url')
    $columns = $orderedColumns | Where-Object { $allColumns -contains $_ }
    
    $sourceData = Invoke-SqliteQuery -DataSource $SourceDBPath -Query "SELECT $($allColumns -join ',') FROM AutoTrackerItems"
    
    if (-not (Test-Path $DestCSVPath)) {
        $columns -join ';' | Set-Content -Path $DestCSVPath -Encoding UTF8
        $destData = @()
    } else {
        $destData = Import-Csv -Path $DestCSVPath -Delimiter ';'
    }
    
    $newEntries = $sourceData | Where-Object {
        $s = $_
        -not ($destData | Where-Object { $_.Id -eq $s.Id -and $_.StartTime -eq $s.StartTime -and $_.EndTime -eq $s.EndTime })
    }
    
    if ($newEntries.Count -gt 0) {
        $newEntries | ForEach-Object {
            $row = $_
            $formattedRow = $columns | ForEach-Object { Format-CSVField -Field $row.$_ }
            $formattedRow -join ';'
        } | Add-Content -Path $DestCSVPath -Encoding UTF8
        
        "$($newEntries.Count) neue Einträge wurden hinzugefügt."
    } else {
        "Keine neuen Einträge gefunden. Die CSV-Datei bleibt unverändert."
    }

    $deletedEntries = $destData | Where-Object {
        $d = $_
        -not ($sourceData | Where-Object { $_.Id -eq $d.Id -and $_.StartTime -eq $d.StartTime -and $_.EndTime -eq $d.EndTime })
    }

    if ($deletedEntries.Count -gt 0) {
        "HINWEIS: $($deletedEntries.Count) Einträge wurden in der Quell-DB gelöscht, bleiben aber in der CSV erhalten."
    }

    # Überprüfe und korrigiere die CSV-Struktur
    $csvContent = Get-Content -Path $DestCSVPath -Raw
    $correctedContent = $csvContent -replace '(?<!\r)\n', "`r`n"
    Set-Content -Path $DestCSVPath -Value $correctedContent -Encoding UTF8 -NoNewline
}

try {
    if (-not (Get-Module -ListAvailable -Name PSSQLite)) {
        Install-Module -Name PSSQLite -Force -Scope CurrentUser
    }
    Sync-ClockifyCSV -SourceDBPath $SourceDBPath -DestCSVPath $DestCSVPath
}
catch {
    Write-Error "Fehler: $_"
}
finally {
    Read-Host "Drücken Sie Enter zum Beenden"
}
