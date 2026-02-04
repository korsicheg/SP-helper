param(
	[Parameter(Mandatory = $true)] $websession,
	[Parameter(Mandatory = $true)] $url,
	[Parameter(Mandatory = $true)] $logHeaders,
	[Parameter(Mandatory = $true)] $users,
	[Parameter(Mandatory = $true)] $requestType,
	$currentDate,
	$firstRun
)

# Timezone setup and Unix timestamp for 2 AM and 7 AM today
$tz = [System.TimeZoneInfo]::FindSystemTimeZoneById("GTB Standard Time")
if ($currentDate) {
	$unixStart = [long]::Parse((Get-Date ($currentDate.AddHours(1)).ToUniversalTime() -UFormat %s))
	$unixEnd = [long]::Parse((Get-Date ($currentDate.AddHours(7)).ToUniversalTime() -UFormat %s))
} else {
	$unixStart = [long]::Parse((Get-Date ((Get-Date).Date.AddHours(1)).ToUniversalTime() -UFormat %s))
	$unixEnd = [long]::Parse((Get-Date ((Get-Date).Date.AddHours(7)).ToUniversalTime() -UFormat %s))
}

# Prepare the request data
$logData = '{"request":"getSystemLogTable","data":{"from":' + $unixStart + ',"to":' + $unixEnd + ',"filter":"' + $requestType[1] + ',"instances":' + ${env:INSTANCES} + ',"users":' + $users + '}}'

# Fetch log response
$logJson = (Invoke-WebRequest -Uri $url -Headers $logHeaders -Method POST -Body $logData -WebSession $websession) | ConvertFrom-Json

# Return 0 if no tableContent or if status indicates an unreachable instance
if (-not $logJson.tableContent.Count -or $logJson.responseStatus[1] -eq "INSTANCE_UNREACHABLE") { return 0 }

# Filter for specific error codes and group them by instance
$filtered = $logJson.tableContent | Where-Object { $_[3] -in @("0465","0466") } | Sort-Object { $_[0],$_[1] }

$grouped = @()
$currentGroup = @()
$prevKey = $null

foreach ($entry in $filtered) {

	$key = "$($entry[0])" # Instance

	if ($key -eq $prevKey -or $prevKey -eq $null) {
		$currentGroup +=,$entry
	} else {
		$grouped +=,@($currentGroup) # Nested group
		$currentGroup = @()
		$currentGroup +=,$entry
	}

	$prevKey = $key
}

# Add the final group
if ($currentGroup.Count -gt 0) {
	$grouped +=,@($currentGroup) # Nested group for the last one
}

# Initialize $body
$body = ""

foreach ($group in $grouped) {
	$instance = $group[0][0]
	$purgeStartUtc = [DateTimeOffset]::FromUnixTimeSeconds([long]($group[0][1] / 1000000)).UtcDateTime
	$purgeEndUtc = [DateTimeOffset]::FromUnixTimeSeconds([long]($group[-1][1] / 1000000)).UtcDateTime

	# Convert UTC times to local time zone
	$purgeStart = [System.TimeZoneInfo]::ConvertTimeFromUtc($purgeStartUtc,$tz)
	$purgeEnd = [System.TimeZoneInfo]::ConvertTimeFromUtc($purgeEndUtc,$tz)
	$purgeTimeElapsed = ($purgeEnd - $purgeStart).TotalMinutes

	$body += "<i>$instance</i><br>Started: $($purgeStart.ToString("dd/MM/yyyy HH:mm:ss"))<br>Ended: $($purgeEnd.ToString("dd/MM/yyyy HH:mm:ss"))<br>Time elapsed (m): $purgeTimeElapsed<br><br>Detailed:<br><pre style='font-size: 0.8rem;'>"

	# Process detailed log entries in groups of 2
	for ($i = 0; $i -lt $group.Count; $i += 2) {
		$startEntry,$endEntry = $group[$i],$group[$i + 1]
		$indexStartUtc = [DateTimeOffset]::FromUnixTimeSeconds([long]($startEntry[1] / 1000000)).UtcDateTime
		$indexEndUtc = [DateTimeOffset]::FromUnixTimeSeconds([long]($endEntry[1] / 1000000)).UtcDateTime
		$indexStart = [System.TimeZoneInfo]::ConvertTimeFromUtc($indexStartUtc,$tz)
		$indexEnd = [System.TimeZoneInfo]::ConvertTimeFromUtc($indexEndUtc,$tz)
		$indexTimeElapsed = ($indexEnd - $indexStart).TotalSeconds

		# Extract purged count and index name
		if ($endEntry[5] -match "index '([^']+)' completed with purging ([\d,]+) entries") {
			$indexName = $matches[1]
			$purgedCount = ($matches[2] -replace ',','') -as [int]
		} else {
			$indexName = "Unknown"
			$purgedCount = "?"
		}

		$body += "Index <b>$indexName</b> purged with $purgedCount entries<br>Time elapsed (s): $indexTimeElapsed<br>"
	}

	$body += "</pre>"
}

return $body
