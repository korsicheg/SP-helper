param(
	[Parameter(Mandatory = $true)] [string]$body,
	[Parameter(Mandatory = $true)] [string]$username,
	$currentRunDate
)

# User map with full email addresses from environment
$userMap = ${env:EMAIL_RECIPIENTS} | ConvertFrom-Json -AsHashtable

# Prepare email variables
if ($currentRunDate) {
	$today = $currentRunDate.ToString("MMMM dd, yyyy")
	$subject = "Morning Safer Payment Stats - Weekends - $today"

} else {
	$today = Get-Date -Format "MMMM dd, yyyy"
	$subject = "Morning Safer Payment Stats - $today"
}

# Initialize to and cc as empty
$to = ""
$cc = ""

# Only proceed if current user is mapped
if ($userMap.ContainsKey($username)) {
	# Exclude the current user and include the rest in TO
	$to = (
		$userMap.GetEnumerator() |
		Where-Object { $_.Key -ne $username } |
		ForEach-Object { $_.Value }
	) -join "; "
	$cc = $userMap[$username]
}

# Wrap body in HTML
$bodyHtml = "<html><body>$body</body></html>"

# Send email using Outlook COM object
try {
	$outlook = New-Object -ComObject Outlook.Application
	$mail = $outlook.CreateItem(0) # 0 = MailItem

	$mail.To = $to
	$mail.CC = $cc
	$mail.Subject = $subject
	$mail.HTMLBody = $bodyHtml

	$mail.Display() # Show the email window
}
catch {
	Write-Error "Failed to create email draft: $_"
}
