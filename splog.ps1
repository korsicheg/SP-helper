. ".\General\functions.ps1"
Load-DotEnv

##############################################################
########## IF NEEDED CHANGE OUTLOOK PREFERENCES HERE #########
##############################################################
$emailMap = ${env:EMAIL_MAP} | ConvertFrom-Json
##############################################################
##############################################################
##############################################################

Logo

# Prompt user for credential source
do {
	$access = Read-Host "Choose access: `n1 - KeePass`n2 - Manual input of login-password`n`nInput"
	switch ($access) {
		'1' {
			$jsonOutput = & ${env:KEEPASS_POWERSHELL_EXE} -NoProfile -ExecutionPolicy Bypass -File ".\General\access_keepass.ps1"
			if ([string]::IsNullOrWhiteSpace($jsonOutput)) { Write-Error "`nKeePass script returned empty output."; exit 1 }

			try { $keepass = $jsonOutput | ConvertFrom-Json }
			catch { Write-Error "`nInvalid JSON from KeePass: $jsonOutput"; exit 1 }

			if (-not $keepass.Success) { Write-Error "`nKeePass login failed: $($keepass.Error)"; exit 1 }

			$username,$password = $keepass.Username,$keepass.Password
		}
		'2' {
			$username = Read-Host "`nEnter login"
			$securePassword = Read-Host "Enter password" -AsSecureString
			$ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
			$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr)
			[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
		}
		default { Write-Warning "`nInvalid selection. Choose 1 or 2.`n`nInput" }
	}
} until ($access -in '1','2')

# URL and Headers initialization
$url = ${env:URL}+'/?{"request":"postRequest"}'
$headers = @{
	'Accept' = 'application/json, text/javascript, */*; q=0.01'
	'Accept-Language' = 'en-US,en;q=0.9,el;q=0.8'
	'Content-Type' = 'application/x-www-form-urlencoded; charset=UTF-8'
	'Origin' = ${env:URL}
	'Referer' = ${env:URL}+'/login'
	'Sec-Fetch-Dest' = 'empty'
	'Sec-Fetch-Mode' = 'cors'
	'Sec-Fetch-Site' = 'same-origin'
	'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36 Edg/136.0.0.0'
	'UserClick' = 'true'
	'sec-ch-ua' = '"Chromium";v="136", "Microsoft Edge";v="136", "Not.A/Brand";v="99"'
	'sec-ch-ua-mobile' = '?0'
	'sec-ch-ua-platform' = '"Windows"'
}

# Login to Safer and get session info
$loginData = & .\General\login_safer.ps1 -Username $username -Password $password -url $url -loginHeaders $headers
if ($loginData -eq $false) { exit 1 }

# Change headers for next requests
$headers['Referer'] = ${env:URL}+'/cluster/log'
$headers['CsrfToken'] = $loginData.csrfToken

# Users to include
$userlist = ${env:USERLIST}
$checkUserlist = ${env:CHECK_USERLIST}

$exit = 0

do {
	$mode = Read-Host "`nChoose mode: `n`n1 - Last night stats`n2 - Weekends stats`n3 - What happened in last 5 minutes`n4 - Run last month User Audit`n5 - Exit script`n`nInput"
	switch ($mode) {
		'1' {
			Logo
			Execution
			$body = & .\SPS\safer_payments_stats.ps1 -WebSession $loginData.websession -url $url -Headers $headers -userlist $userlist
			sendMail -Username $username -EmailMap $emailMap
			Write-Host ""
			$exitChoice = Read-Host "Do you want to exit? y/n"
			if ($exitChoice -match '^[YyΥυНн]') {
				$exit = 1
			} else {
				Write-Host ""
				Logo
			}
		}
		'2' {
			$daysBack = Read-Host "How many days back you want to go?`nExample: if run on Monday after weekends, input 2`nInput"
			Logo
			Execution
			$startDate = (Get-Date).Date.AddDays(-$daysBack)
			$firstRun = $true
			$totalDays = [int]$daysBack + 1
			for ($i = 0; $i -lt $totalDays; $i++) {
				$currentRunDate = $startDate.AddDays($i)
				Write-Progress -Id 1 -PercentComplete (([int]$i / $totalDays) * 100) `
					-Status "Running Weekend Stats, date: $($currentRunDate.ToString('MMMM dd, yyyy'))" `
					-Activity "Executing..." `
					-CurrentOperation "Date: $($currentRunDate.ToString('MMMM dd, yyyy'))"
				$body = & .\SPS\safer_payments_stats -WebSession $loginData.websession -url $url -Headers $headers -userlist $userlist -currentRunDate $currentRunDate -firstRun $firstRun
				sendMail -Username $username -EmailMap $emailMap -currentRunDate $currentRunDate
				Sleep 5
				if ($firstRun) {
					$firstRun = $false
				} 
			}
			Write-Progress -Id 1 -PercentComplete 100 -Status "Completed" -Activity "All scripts executed" -CurrentOperation "Done"
			Write-Host ""
			$exitChoice = Read-Host "Do you want to exit? y/n"
			if ($exitChoice -match '^[YyΥυНн]') {
				$exit = 1
			} else {
				Write-Host ""
				Logo
			}
		}
		'3' {
			Logo
			Execution
			& .\SPS\last_5_minutes.ps1 -WebSession $loginData.websession -url $url -Headers $headers -userlist $userlist
			Write-Host ""
			$exitChoice = Read-Host "Do you want to exit? y/n"
			if ($exitChoice -match '^[YyΥυНн]') {
				$exit = 1
			} else {
				Write-Host ""
				Logo
			}
		}
		'4' {
			Logo
			Execution
			$unixStart = ([datetimeoffset]((Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0).AddMonths(-1))).ToUnixTimeSeconds()
			$unixEnd = ([datetimeoffset]((Get-Date -Day 1 -Hour 23 -Minute 59 -Second 59).AddDays(-1))).ToUnixTimeSeconds()
			& .\SPS\user_logs.ps1 -WebSession $loginData.websession -url $url -logHeaders $headers -userlist $checkUserlist -unixStart $unixStart -unixEnd $unixEnd
			Write-Host ""
			$exitChoice = Read-Host "Do you want to exit? y/n"
			if ($exitChoice -match '^[YyΥυНн]') {
				$exit = 1
			} else {
				Write-Host ""
				Logo
			}
		}
		'5' {
			$exit = 1
			continue
		}
		default { Write-Warning "Invalid selection. Choose 1, 2, 3, 4 or 5." }
	}
} until ($exit -eq 1)



# Logout
.\General\logout_safer.ps1 -WebSession $loginData.websession -logoutHeaders $headers
Remove-DotEnvVars
