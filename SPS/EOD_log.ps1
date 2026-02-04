param(
	[Parameter(Mandatory = $true)] $websession,
	[Parameter(Mandatory = $true)] $url,
	[Parameter(Mandatory = $true)] $logHeaders,
	[Parameter(Mandatory = $true)] $users,
	[Parameter(Mandatory = $true)] $requestType,
	$currentDate,
	$firstRun
)

# Timezone setup and Unix timestamp for 2 AM and 6 AM today
$tz = [System.TimeZoneInfo]::FindSystemTimeZoneById("GTB Standard Time")
if ($currentDate) {
	$unixStart = [long]::Parse((Get-Date ($currentDate.Date.AddHours(1)).ToUniversalTime() -UFormat %s))
	$unixEnd = [long]::Parse((Get-Date ($currentDate.Date.AddHours(7)).ToUniversalTime() -UFormat %s))
} else {
	$unixStart = [long]::Parse((Get-Date ((Get-Date).Date.AddHours(1)).ToUniversalTime() -UFormat %s))
	$unixEnd = [long]::Parse((Get-Date ((Get-Date).Date.AddHours(7)).ToUniversalTime() -UFormat %s))
}

# Prepare request payload
$logData = '{"request":"getSystemLogTable","data":{"from":' + $unixStart + ',"to":' + $unixEnd + ',"filter":"' + $requestType[1] + '","instances":' + ${env:INSTANCES} + ',"users":' + $users + '}}'

# Get log response and filter for error codes
$logJson = (Invoke-WebRequest -Uri $url -Headers $logHeaders -Method POST -Body $logData -WebSession $websession) | ConvertFrom-Json
$filtered = $logJson.tableContent | Where-Object { $_[3] -in @("0095","0096") } | Sort-Object { $_[0],$_[3] }

# Initialize body
$body = ""

# Process filtered entries in pairs (i.e., start and finish)
for ($i = 0; $i -lt $filtered.Count; $i += 2) {
	$entry1,$entry2 = $filtered[$i],$filtered[$i + 1]

	# Extract details
	$instanceName = [System.Text.RegularExpressions.Regex]::Unescape($entry1[0])
	$timeStartUtc = [DateTimeOffset]::FromUnixTimeSeconds([long]($entry1[1] / 1000000)).UtcDateTime
	$timeFinishUtc = [DateTimeOffset]::FromUnixTimeSeconds([long]($entry2[1] / 1000000)).UtcDateTime

	# Convert times to local timezone
	$timeStart = [System.TimeZoneInfo]::ConvertTimeFromUtc($timeStartUtc,$tz)
	$timeFinish = [System.TimeZoneInfo]::ConvertTimeFromUtc($timeFinishUtc,$tz)

	# Calculate elapsed time in minutes
	$timeElapsed = ($timeFinish - $timeStart).TotalMinutes

	# Append formatted details to body
	$body += "<i>$instanceName</i><br>Started: $($timeStart.ToString('dd/MM/yyyy HH:mm:ss'))<br>Ended: $($timeFinish.ToString('dd/MM/yyyy HH:mm:ss'))<br>Time elapsed (m): $timeElapsed<br><br>"
}

return $body
