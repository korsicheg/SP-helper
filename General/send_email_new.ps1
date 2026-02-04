param(
	[Parameter(Mandatory = $true)] [string]$body,
	[Parameter(Mandatory = $true)] [string]$username,
	$currentRunDate
)

# User map with their full email addresses from environment
$userMap = ${env:EMAIL_RECIPIENTS} | ConvertFrom-Json -AsHashtable

# Get current script directory or fallback to the current location
$outputDir = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
$outputPath = Join-Path $outputDir "DailySaferStats.eml"

# Initialize TO, CC, and FROM based on the current user
# Only proceed if current user is mapped
if ($userMap.ContainsKey($username)) {
	# Exclude the current user and include the rest in TO
	$to = (
		$userMap.GetEnumerator() |
		Where-Object { $_.Key -ne $username } |
		ForEach-Object { $_.Value }
	) -join "; "
	$cc = $userMap[$username]
	$from = $cc
}

# Email parameters
if ($currentRunDate) {
	$today = $currentRunDate.ToString("MMMM dd, yyyy")
	$subject = "Morning Safer Payment Stats - Weekends - $today"

} else {
	$today = Get-Date -Format "MMMM dd, yyyy"
	$subject = "Morning Safer Payment Stats - $today"
}
$bodyHtml = "<html><body>$body</body></html>"

# Create email content in the correct format
$emailContent = @"
X-Unsent: 1
From: $from
To: $to
CC: $cc
Subject: $subject
Date: $(Get-Date -Format "ddd, dd MMM yyyy HH:mm:ss K")
MIME-Version: 1.0
Content-Type: text/html; charset=utf-8
Content-Transfer-Encoding: 7bit

$bodyHtml
"@

# Write content to the .eml file with correct encoding
[System.IO.File]::WriteAllText($outputPath,$emailContent,[System.Text.Encoding]::UTF8)

# Open the .eml file
Start-Process $outputPath
