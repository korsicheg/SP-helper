param(
	[Parameter(Mandatory = $true)] $websession,
	[Parameter(Mandatory = $true)] $url,
	[Parameter(Mandatory = $true)] $logHeaders,
	[Parameter(Mandatory = $true)] $users,
	[Parameter(Mandatory = $true)] $requestType,
	$currentDate,
	$firstRun
)

# Fetch log response and parse it as JSON
$indexJson = (Invoke-WebRequest -Uri "${env:URL}/?{`"request`":`"getStatusAlarmIndicatorsDisplay`"}" -Headers $logHeaders -Method GET -WebSession $websession) | ConvertFrom-Json

# Initialize a list to hold table rows
$rows = @()

$body = @"
    <table style="border-collapse: collapse; width:100%; table-layout: fixed; overflow-wrap: break-word;">
        <tr><th style="border: 1px solid black;">Index</th><th style="border: 1px solid black;">Fill level</th></tr>
"@

Add-Type -AssemblyName System.Web

foreach ($item in $indexJson.statusAlarmIndicators) {
    $name = [System.Web.HttpUtility]::HtmlDecode($item.replacements.'{name}')

    if ($name -like 'Index fill level - *') {
        # Remove prefix
        $indexName = $name -replace '^Index fill level - ', ''

        # Split by " - " and take last segment
        $indexNameParts = $indexName -split ' - '
        $indexName = $indexNameParts[-1]

        # Replace dashes with underscores
        $indexName = $indexName -replace '-', '_'

        # Strip any non-alphanumerics (including leftover parentheses)
        $indexName = $indexName -replace '[^a-zA-Z0-9_]', ''
		
        $valueStr = $item.replacements.'{value}'
        $level = [double]$valueStr

        # Determine background color
        $bgColor = ""
        if ($level -gt 95) {
            $bgColor = "background-color:red;"
        } elseif ($level -gt 90) {
            $bgColor = "background-color:yellow;"
        }

        # Apply inline color style if needed
        if ($bgColor) {
            $rows += "<tr><td style='border: 1px solid black;'>$indexName</td><td style='$bgColor border: 1px solid black;'>$valueStr</td></tr>"
        } else {
            $rows += "<tr><td style='border: 1px solid black;'>$indexName</td><td style='border: 1px solid black;'>$valueStr</td></tr>"
        }
    }
}

$body += ($rows -join "`n")
$body += @"
    </table>
"@

return $body
