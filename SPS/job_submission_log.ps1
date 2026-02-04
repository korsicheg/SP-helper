param(
	[Parameter(Mandatory = $true)] $websession,
	[Parameter(Mandatory = $true)] $url,
	[Parameter(Mandatory = $true)] $logHeaders,
	[Parameter(Mandatory = $true)] $users,
	[Parameter(Mandatory = $true)] $requestType,
	$currentDate,
	$firstRun
)

# Get Unix timestamps for 12 AM and 7 AM (current day)
if ($currentDate) {
	$unixStart = [long](($currentDate.Date.ToUniversalTime() - [datetime]'1970-01-01').TotalSeconds)
	$unixEnd = [long]::Parse((Get-Date ($currentDate.Date.AddHours(9)) -UFormat %s))
} else {
	$unixStart = [long](((Get-Date).Date.ToUniversalTime() - [datetime]'1970-01-01').TotalSeconds)
	$unixEnd = [long]::Parse((Get-Date ((Get-Date).Date.AddHours(9)) -UFormat %s))
}

# Construct the log request data
$logData = '{"request":"getSystemLogTable","data":{"from":' + $unixStart + ',"to":' + $unixEnd + ',"filter":"' + $requestType[1] + ',"instances":' + ${env:INSTANCES} + ',"users":' + $users + '}}'

# Fetch log response and parse it as JSON
$logJson = (Invoke-WebRequest -Uri $url -Headers $logHeaders -Method POST -Body $logData -WebSession $websession) | ConvertFrom-Json

# Exit early if response is empty or unreachable
if (-not $logJson.tableContent.Count -or $logJson.responseStatus[1] -eq "INSTANCE_UNREACHABLE") { return 0 }

$jobCounter = 0

# Filter and build HTML body for the filtered error messages
$body = ($logJson.tableContent |
    Where-Object { $_[3] -in @("0193","0192") } |
    ForEach-Object {
		$jobCounter += 1
        $msg = [System.Text.RegularExpressions.Regex]::Unescape($_[5])

        # Cut everything after "records total),"
        if ($msg -match 'records total') {
            $msg = $msg -replace '(records total).*', 'records total)'
        }

        # Bold any message that contains "found nothing to do"
        if ($msg -match "found nothing to do") {
            $msg = "<b>$msg</b>"
        }

        "<li>$jobCounter. $msg</li>"
    }) -join "`r`n"

return $body
