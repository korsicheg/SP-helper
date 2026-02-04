#########################################################################
###################### CHANGES FOR KEEPASS TO WORK ######################
#########################################################################
#   If you want to run Keepass, change the following:                   #
#    Line 17: Put your Database path in single quotes                   #
#    Line 53: Put your entry title in single quotes, case sensitive     #
#########################################################################
#########################################################################
#########################################################################

[System.Reflection.Assembly]::LoadFrom(${env:KEEPASS_EXE_PATH}) | Out-Null
[KeePass.Program]::CommonInitialize()


try {
	$ioc = [KeePassLib.Serialization.IOConnectionInfo]::FromPath(
		#↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ CHANGE KEEPASS LOCATION HERE ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓#
		${env:KEEPASS_PATH}
		#↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ CHANGE KEEPASS LOCATION HERE ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑#
	)

	$maxAttempts = 3
	$attempt = 0
	$pd = [KeePassLib.PwDatabase]::new()
	$success = $false

	while ($attempt -lt $maxAttempts -and -not $success) {
		$attempt++
		$masterPassword = Read-Host -AsSecureString "`nEnter master password (Attempt $attempt of $maxAttempts)"
		$securePasswordPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($masterPassword)
		$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($securePasswordPtr)

		try {
			$ck = [KeePassLib.Keys.CompositeKey]::new()
			$kp = [KeePassLib.Keys.KcpPassword]::new($plainPassword)
			$ck.AddUserKey($kp)

			$pd.Open($ioc,$ck,$null)
			$success = $true
		} catch {
			if ($attempt -eq $maxAttempts) {
				# On final failure, output JSON and exit
				Write-Output (@{ Success = $false; Error = $_.Exception.Message } | ConvertTo-Json -Compress)
				exit 1
			}
		} finally {
			[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($securePasswordPtr)
		}
	}

	# Now extract the entry
	$sp = [KeePassLib.SearchParameters]::new()
	#↓↓↓↓↓↓↓↓↓↓ CHANGE ENTRY TITLE HERE ↓↓↓↓↓↓↓↓↓↓#
	$sp.SearchString = ${env:KEEPASS_ENTRY_NAME}
	#↑↑↑↑↑↑↑↑↑↑ CHANGE ENTRY TITLE HERE ↑↑↑↑↑↑↑↑↑↑#

	$pl = [KeePassLib.Collections.PwObjectList[KeePassLib.PwEntry]]::new()
	$pd.RootGroup.SearchEntries($sp,$pl)

	if ($pl.Count -eq 0) {
		Write-Output (@{ Success = $false; Error = "No entry found with title '$($sp.SearchString)'" } | ConvertTo-Json -Compress)
		exit 1
	}

	$entry = $pl.GetAt(0)
	$username = $entry.Strings.ReadSafe([KeePassLib.PwDefs]::UserNameField)
	$password = $entry.Strings.ReadSafe([KeePassLib.PwDefs]::PasswordField)

	# Output JSON result
	Write-Output (@{
			Success = $true
			Username = $username
			Password = $password
		} | ConvertTo-Json -Compress)
	exit 0

} finally {
	if ($pd -and $pd.IsOpen) {
		$pd.Close()
	}
	[KeePass.Program]::CommonTerminate()
}
