param(
	[Parameter(Mandatory = $true)] [string]$username,
	[Parameter(Mandatory = $true)] [string]$password,
	[Parameter(Mandatory = $true)] [string]$url,
	[Parameter(Mandatory = $true)] $loginHeaders
)

$maxAttempts = 3
$attempt = 0
$success = $false
$loginCheckConfirmed = $false

while ($attempt -lt $maxAttempts -and -not $success) {
	$attempt++

	$loginData = '{"request":"login","data":{"login":"' + $username + '","password":"' + $password + '"}}'

	try {
		$loginJson = (Invoke-WebRequest -Uri $url -Headers $loginHeaders -Method POST -Body $loginData -SessionVariable websession) | ConvertFrom-Json
		if ($loginJson.responseStatus[0] -ne 'E') {
			$success = $true
			break
		} else {
			throw "Login response indicates failure."
		}
	} catch {
		Write-Warning "Login failed (Attempt $attempt of $maxAttempts).`n"

		if ($attempt -lt $maxAttempts) {
			if (-not $loginCheckConfirmed) {
				if ($loginCheck -match '^[NnΝν]') {
					$username = Read-Host "Enter login"
				}
				if ($loginCheck -match '^[YyΥυ]') {
					$loginCheckConfirmed = $true # Set flag to true once user confirms login
				}
			}

			if ((Read-Host "Show previously entered password? (y/n)") -match '^[YyΥυ]') {
				Write-Host "Last entered password: $password`n"
			}

			$securePassword = Read-Host "Enter password" -AsSecureString
			$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
			$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr)
			[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
		} else {
			Write-Host "`nWrong login/password. Exiting.`n"
			return $false
		}
	}
}

Logo
Login -Username $username

return @{
	Success = $success
	csrfToken = $loginJson.csrfToken
	websession = $websession
}
