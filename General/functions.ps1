function getUserName {
	param(
		$username
	)

	$userMap = ${env:USER_MAP} | ConvertFrom-Json

	return $userMap.$username
}

function ClearScreen {
    if ($host.Name -eq 'ConsoleHost') {
        [console]::Clear()
    } else {
        Write-Host "`e[2J`e[H"
    }
}

function Logo {
	Clear-Host
	$title = "Safer Payments Statistics Maker ©"
	$line = "=" * $title.Length

	Write-Host ""
	Write-Host $line -ForegroundColor Cyan
	Write-Host $title -ForegroundColor Yellow
	Write-Host $line -ForegroundColor Cyan
	Write-Host ""
}

function Login {
	param(
		$username
	)
	# Get the username
	$userName = getUserName -Username $username

	$title = "Welcome $userName"
	$line = "=" * $title.Length

	Write-Host $line -ForegroundColor White
	Write-Host $title -ForegroundColor Green
	Write-Host $line -ForegroundColor White
	Write-Host ""
}

function Execution {
	$title = "Execution..."
	$line = "*" * $title.Length

	Write-Host $line -ForegroundColor White
	Write-Host $title -ForegroundColor White
	Write-Host $line -ForegroundColor White
	Write-Host ""
}

function Logout {
	param(
		$username
	)

	# Get the username
	$userName = getUserName -Username $username

	$title = "Goodbye! Successfully logged out."
	$line = "=" * $title.Length

	Write-Host $line -ForegroundColor White
	Write-Host $title -ForegroundColor Red
	Write-Host $line -ForegroundColor White
	Write-Host ""
}

function sendMail {
	param(
		$username,
		$emailMap,
		$currentRunDate
	)
	
	switch ($emailMap.$username) {
		"New" {
			.\General\send_email_new.ps1 -Body $body -Username $username -currentRunDate $currentRunDate
		}
		"Classic" {
			.\General\send_email_old.ps1 -Body $body -Username $username -currentRunDate $currentRunDate
		}
	}
}

function Load-DotEnv {
    param([string]$Path = ".env")

    $script:LoadedEnvVars = @()

    Get-Content $Path | ForEach-Object {
        if ($_ -match "^(.*?)=(.*)$") {
            $name  = $matches[1]
            $value = $matches[2]

            [System.Environment]::SetEnvironmentVariable($name, $value)
            $script:LoadedEnvVars += $name
        }
    }
}

function Remove-DotEnvVars {
    foreach ($var in $script:LoadedEnvVars) {
        [System.Environment]::SetEnvironmentVariable($var, $null)
    }
}
