param(
	[Parameter(Mandatory = $true)] $websession,
	[Parameter(Mandatory = $true)] $url,
	[Parameter(Mandatory = $true)] $logHeaders,
	[Parameter(Mandatory = $true)] $users,
	[Parameter(Mandatory = $true)] $requestType,
	$currentDate,
	$firstRun
)

$tz = [System.TimeZoneInfo]::FindSystemTimeZoneById("GTB Standard Time")
$epoch = Get-Date "1970-01-01 00:00:00"
if ($currentDate) {
	if ($firstRun) {
		$unixStart = [int](($currentDate.AddDays(-1).Date.AddHours(17).ToUniversalTime() - $epoch).TotalSeconds)
		$unixCurrent = [int](($currentDate.ToUniversalTime() - $epoch).TotalSeconds)
	} else {
		$unixStart = [int](($currentDate.ToUniversalTime() - $epoch).TotalSeconds)
		$unixCurrent = [int](($currentDate.ToUniversalTime().AddHours(23).AddMinutes(59) - $epoch).TotalSeconds)
	}
} else {
	$unixStart = [int](((Get-Date).AddDays(-1).Date.AddHours(17).ToUniversalTime() - $epoch).TotalSeconds)
	$unixCurrent = [int](((Get-Date).ToUniversalTime() - $epoch).TotalSeconds)
}

$allData = @()
for ($start = $unixStart; $start -lt $unixCurrent; $start += 7201) {
	$end = $start + 7200
	$logData = '{"request":"getSystemLogTable","data":{"from":' + $start + ',"to":' + $end + ',"filter":"' + $requestType[1] + ',"instances":' + ${env:INSTANCES} + ',"users":' + $users + '}}'
	$logJson = (Invoke-WebRequest -Uri $url -Headers $logHeaders -Method POST -Body $logData -WebSession $websession | ConvertFrom-Json)
	$allData += $logJson.tableContent
}

if (-not $allData) { return $body = 0 }

# Optional filtering for type 'W'
if ($requestType[1] -eq "W") {
    $sortedData = $allData | Where-Object { $_[3] -ne "0364" } | Sort-Object { $_[1] }
} else {
    $sortedData = $allData | Sort-Object { $_[1] }
}

# Group data by key: Instance|LogLevel|ID
$grouped = @()
$currentGroup = @()
$prevKey = $null

foreach ($entry in $sortedData) {
	$key = "$($entry[0])|$($entry[2])|$($entry[3])"
	if ($key -eq $prevKey -or -not $prevKey) {
		$currentGroup +=,$entry
	} else {
		$grouped +=,@($currentGroup)
		$currentGroup = @()
		$currentGroup +=,$entry
	}
	$prevKey = $key
}
if ($currentGroup) { $grouped +=,@($currentGroup) }

# HTML table header
$body = @'
<table style="border-collapse: collapse;">
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

foreach ($entries in $grouped) {
	$count = $entries.Count
	$timestamps = $entries | ForEach-Object { [DateTimeOffset]::FromUnixTimeSeconds($_[1] / 1000000).UtcDateTime }
	$startTime = [System.TimeZoneInfo]::ConvertTimeFromUtc(($timestamps | Measure-Object -Minimum).Minimum,$tz).ToString("dd/MM/yyyy HH:mm:ss")
	$endTime = [System.TimeZoneInfo]::ConvertTimeFromUtc(($timestamps | Measure-Object -Maximum).Maximum,$tz).ToString("dd/MM/yyyy HH:mm:ss")

	$last = $entries[-1]
	$instance,$rawTime,$level,$dataId,$user,$message,$comment = $last
	$timestamp = [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTimeOffset]::FromUnixTimeSeconds($rawTime / 1000000).UtcDateTime,$tz).ToString("dd/MM/yyyy HH:mm:ss")

	if ($count -eq 1) {
		$body += "<tr><td style='border: 1px solid black;'>$instance</td><td style='border: 1px solid black;'>$timestamp</td><td style='border: 1px solid black;'>$level</td><td style='border: 1px solid black;'>$dataId</td><td style='border: 1px solid black;'>$user</td><td style='border: 1px solid black;'>$message</td><td style='border: 1px solid black;'>$comment</td></tr>"
	} else {
		$body += "<tr><td colspan='7' style='border: 1px solid black; border-bottom: 1px dotted;'>Following $($requestType[0].ToLower()) happened <b>$count</b> times in a row, from $startTime until $endTime. Last $($requestType[0].ToLower()):</td></tr>"
		$body += "<tr><td style='border: 1px solid black;border-top: 1px dotted;'>$instance</td><td style='border: 1px solid black;border-top: 1px dotted;'>$timestamp</td><td style='border: 1px solid black;border-top: 1px dotted;'>$level</td><td style='border: 1px solid black;border-top: 1px dotted;'>$dataId</td><td style='border: 1px solid black;border-top: 1px dotted;'>$user</td><td style='border: 1px solid black;border-top: 1px dotted;'>$message</td><td style='border: 1px solid black;border-top: 1px dotted;'>$comment</td></tr>"
	}
}
$body += "</table>"
return $body
