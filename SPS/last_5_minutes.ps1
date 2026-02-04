param(
	[Parameter(Mandatory = $true)] $websession,
	[Parameter(Mandatory = $true)] $url,
	[Parameter(Mandatory = $true)] $headers,
	[Parameter(Mandatory = $true)] $userlist
)

# Build contents table
$body = @"
<a name="Top"><b>Contents</b></a><br/>
<a href="#Audit"><strong style="font-weight:normal;">Audit Log</strong></a><br/>
<a href="#System"><strong style="font-weight:normal;">System Log</strong></a><br/><br/>
"@

$tz = [System.TimeZoneInfo]::FindSystemTimeZoneById("GMT Standard Time")
$unixStart = [int][double]::Parse((Get-Date).AddMinutes(-5).AddHours(2).ToUniversalTime().Subtract([datetime]'1970-01-01T00:00:00Z').TotalSeconds)
$unixEnd = [int][double]::Parse((Get-Date).AddHours(2).ToUniversalTime().Subtract([datetime]'1970-01-01T00:00:00Z').TotalSeconds)


$logData = '{"request":"getSystemLogTable","data":{"from":' + $unixStart + ',"to":' + $unixEnd + ',"filter":"CDINWEFAX","instances":' + ${env:INSTANCES} + ',"users":' + $userlist + '}}'
$logJson = (Invoke-WebRequest -Uri $url -Headers $headers -Method POST -Body $logData -WebSession $websession) | ConvertFrom-Json

# HTML table header
$body += @'
<hr><a name="System"><b>System Table</b></a>
<table style="border-collapse: collapse; width:100%; table-layout: fixed; overflow-wrap: break-word;">
<colgroup>
<col style="width: 20ch;">
<col style="width: 30ch;">
<col style="width: 20ch;">
<col>
<col>
<col>
<col>
</colgroup>
<tr>
<th style="border: 1px solid black;">Instance</th>
<th style="border: 1px solid black;">Timestamp</th>
<th style="border: 1px solid black;">Log level</th>
<th style="border: 1px solid black;">ID</th>
<th style="border: 1px solid black;">User</th>
<th style="border: 1px solid black;">Message</th>
<th style="border: 1px solid black;">Comment</th>
</tr>
'@

foreach ($entry in $logJson.tableContent) {
	$instance,$rawTime,$level,$dataId,$user,$message,$comment = $entry
	$timestamp = [System.TimeZoneInfo]::ConvertTime([DateTimeOffset]::FromUnixTimeSeconds($rawTime / 1000000), $tz).AddHours(2).ToString("dd/MM/yyyy HH:mm:ss")

	$body += "<tr><td style='border: 1px solid black;'>$instance</td><td style='border: 1px solid black;'>$timestamp</td><td style='border: 1px solid black;'>$level</td><td style='border: 1px solid black;'>$dataId</td><td style='border: 1px solid black;'>$user</td><td style='border: 1px solid black;'>$message</td><td style='border: 1px solid black;'>$comment</td></tr>"
}
$body += "</table>"

$logData = '{"request":"getAuditLogTable","data":{"from":' + $unixStart + ',"to":' + $unixEnd + ',"filter":"CDINWEFAX","instances":' + ${env:INSTANCES} + ',"users":' + $userlist + '}}'
$logJson = (Invoke-WebRequest -Uri $url -Headers $headers -Method POST -Body $logData -WebSession $websession) | ConvertFrom-Json

# HTML table header
$body += @'
<hr><a name="Audit"><b>Audit Table</b></a>
<table style="border-collapse: collapse; width:100%; table-layout: fixed; overflow-wrap: break-word;">
<tr>
<th style="border: 1px solid black;">Instance</th>
<th style="border: 1px solid black;">Timestamp</th>
<th style="border: 1px solid black;">Log level</th>
<th style="border: 1px solid black;">ID</th>
<th style="border: 1px solid black;">User</th>
<th style="border: 1px solid black;">Message</th>
<th style="border: 1px solid black;">Comment</th>
</tr>
'@

foreach ($entry in $logJson.tableContent) {
	$instance,$rawTime,$level,$dataId,$user,$message,$comment = $entry
	$timestamp = [System.TimeZoneInfo]::ConvertTime([DateTimeOffset]::FromUnixTimeSeconds($rawTime / 1000000), $tz).AddHours(2).ToString("dd/MM/yyyy HH:mm:ss")

	$body += "<tr><td style='border: 1px solid black;'>$instance</td><td style='border: 1px solid black;'>$timestamp</td><td style='border: 1px solid black;'>$level</td><td style='border: 1px solid black;'>$dataId</td><td style='border: 1px solid black;'>$user</td><td style='border: 1px solid black;'>$message</td><td style='border: 1px solid black;'>$comment</td></tr>"
}
$body += "</table>"

# Wrap in complete HTML
$htmlContent = @"
<html>
<head>
    <meta charset="UTF-8">
    <title>Log Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { padding: 8px; border: 1px solid black; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
$body
</body>
</html>
"@

# Define output path
$outputPath = Join-Path -Path $env:TEMP -ChildPath "log_report.html"

# Write to file
$htmlContent | Set-Content -Path $outputPath -Encoding UTF8

# Open in default browser
Start-Process $outputPath
