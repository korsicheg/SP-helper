param(
	[Parameter(Mandatory = $true)] $websession,
	[Parameter(Mandatory = $true)] $url,
	[Parameter(Mandatory = $true)] $headers,
	[Parameter(Mandatory = $true)] $userlist,
	$currentRunDate,
	$firstRun
)

$basePath = Split-Path -Parent $MyInvocation.MyCommand.Definition

$scriptList = @()
$scriptPath = Join-Path $basePath "WEFX_log.ps1"
$scriptList += (1..4 | ForEach-Object { $scriptPath })

$additionalScripts = @(
    "index_fill.ps1",
    "job_submission_log.ps1",
    "EOD_log.ps1",
    "purge_log.ps1"
) | ForEach-Object { Join-Path $basePath $_ }

$scriptList += $additionalScripts

$scriptTitles = @(
	@("Error","E"),@("Fatal","F"),@("Emergency","X"),@("Warning","W"),
	@("Indexes","I"),@("Jobs","ID"),@("EOD","I"),@("Purge","I")
)

# Build contents table
$body = @"
<a name="Top"><b>Contents</b></a><br/>
<a href="#Error"><strong style="font-weight:normal;">Errors</strong></a><br/>
<a href="#Fatal"><strong style="font-weight:normal;">Fatal errors</strong></a><br/>
<a href="#Emergency"><strong style="font-weight:normal;">Emergency errors</strong></a><br/>
<a href="#Warning"><strong style="font-weight:normal;">Warnings</strong></a><br/>
<a href="#Indexes"><strong style="font-weight:normal;">Indexes</strong></a><br/>
<a href="#Jobs"><strong style="font-weight:normal;">Job info</strong></a><br/>
<a href="#EOD"><strong style="font-weight:normal;">EOD info</strong></a><br/>
<a href="#Purge"><strong style="font-weight:normal;">Purge info</strong></a><br/><br/><hr>
"@

# Execute each log script and append result
for ($i = 0; $i -lt $scriptList.Count; $i++) {
	$script = $scriptList[$i]
	$title = $scriptTitles[$i][0]

	Write-Progress -Id 2 -PercentComplete (($i / $scriptList.Count) * 100) `
 		-Status "Running $title logs" -Activity "Executing..." -CurrentOperation "Script: $script"

	$result = & $script -WebSession $websession -url $url -logHeaders $headers -users $userlist -requestType $scriptTitles[$i] -currentDate $currentRunDate -firstRun $firstRun

	$body += if ($result -eq 0) {
		"<br><a name='$title'><b>$title</b></a> <a href='#Top'><strong>Top</strong></a><br/><br/>Nothing was recorded today.<br><br>"
	} else {
		"<br><a name='$title'><b>$title</b></a> <a href='#Top'><strong>Top</strong></a><br/><br/>$result<br>"
	}

	if ($i -lt $scriptList.Count - 1) { $body += "<hr>" }

	Start-Sleep -Seconds 1 # For beautiful progress bar
}

Write-Progress -Id 2 -PercentComplete 100 -Status "Completed" -Activity "All scripts executed" -CurrentOperation "Done"

return $body
