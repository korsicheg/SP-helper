param(
	[Parameter(Mandatory = $true)] $websession,
	[Parameter(Mandatory = $true)] $logoutHeaders
)

# Define URL for logout request
$url = ${env:URL}+'/?{%22request%22:%22logout%22}'

# Send logout request and output success message
Invoke-WebRequest -Uri $url -Headers $logoutHeaders -WebSession $websession | Out-Null
Logout -Username $username
