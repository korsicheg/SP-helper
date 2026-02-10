param(
    [Parameter(Mandatory = $true)] $websession,
    [Parameter(Mandatory = $true)] $url,
    [Parameter(Mandatory = $true)] $logHeaders,
    [Parameter(Mandatory = $true)] $userlist,
	[Parameter(Mandatory = $true)] $unixStart,
	[Parameter(Mandatory = $true)] $unixEnd
)
$csvMMMMyyyy = (Get-Date ([datetimeoffset]::FromUnixTimeSeconds($unixEnd).UtcDateTime) -Format "MMMMyyyy")

# Define CSV path and headers
$csvPath = $csvMMMMyyyy + "UserQueries.csv"
$csvHeaders = "Instance","Timestamp","Log","ID","User","Query Name","Index searched","Message","Comment"

# Write CSV header once, or resume from last entry
if (-not (Test-Path $csvPath)) {
    $csvHeaders -join "," | Out-File -FilePath $csvPath -Encoding UTF8
} else {
    $lastLine = Get-Content $csvPath -Tail 1
    if ($lastLine -and $lastLine -ne ($csvHeaders -join ",")) {
        $lastEntry = $lastLine | ConvertFrom-Csv -Header $csvHeaders
        $unixStart = ([datetimeoffset][datetime]$lastEntry.Timestamp).ToUnixTimeSeconds() + 1
    }
}

# Calculate total days
$totalDays = [math]::Ceiling(($unixEnd - $unixStart) / 86400)

# Get the first midnight >= unixStart
$currentMidnight = [int]([DateTimeOffset](Get-Date -UnixTimeSeconds $unixStart -Hour 0 -Minute 0 -Second 0)).ToUnixTimeSeconds()
if ($currentMidnight -lt $unixStart) {
    $currentMidnight += 86400
}

# Cache query definition once (instead of fetching for every record)
$queryUid = ${env:QUERY_UID}
$getQueryInfo = '{"request":"get","uid":' + $queryUid + ',"data":{}}'
$baseQuery = Invoke-RestMethod -Uri $url -Headers $logHeaders -Method POST -Body $getQueryInfo -WebSession $websession

for ($start = $unixStart; $start -lt $unixEnd; $start += 901) {
    $end = $start + 900
	if ($end -gt $unixEnd) { $end = $unixEnd }
	
    $logHeaders['Referer'] = ${env:URL}+'/cluster/log'

    $logData = '{"request":"getAuditLogTable","data":{"from":' + $start + ',"to":' + $end + ',"filter":"I","instances":' + ${env:INSTANCES} + ',"users":' + $userlist + '}}'
    $logJson = Invoke-RestMethod -Uri $url -Headers $logHeaders -Method POST -Body $logData -WebSession $websession

    $logHeaders['Referer'] = ${env:URL}+'/investigation/queries/' + $queryUid
	
	$oldIndexUrid = 0
	
	$results = @()
	# Initialize counters
	$totalRecords = 0
	$totalTimeMs  = 0

    foreach ($row in $logJson.tableContent) {
        # Apply filters
        if (($row[4] -like '5*') -and ($row[3] -eq '0824')) {
			$elapsed = [System.Diagnostics.Stopwatch]::StartNew()

            # Clean values
            $cleanRow = $row | ForEach-Object { $_ -replace '&#40;', '(' -replace '&#41;', ')' }

            # Extract query name and index urid with regex
            $queryName = ([regex]::Match($cleanRow[5], "'([^']+)'")).Groups[1].Value
            $indexUrid = ([regex]::Match($cleanRow[5], "index value urid=([0-9,]+)")).Groups[1].Value -replace ",", ""
			if ($indexUrid -ne $oldIndexUrid) {
				# Build data selection
				$checkDataSelection = '{"request":"checkDataSelection","type":"query","data":{"mandators":[' + ${env:MANDATOR_ID} + '],"periodType":"RecordsAbsolute","desired":{"fromUrid":"' + $indexUrid + '","fromRecord":2417652428,"fromTimestamp":1685606400,"fromDays":1,"toUrid":' + $indexUrid + ',"toRecord":2,"toTimestamp":1687035540,"toDays":0},"incDdc":true}}'
				$dataSelectionJson = Invoke-RestMethod -Uri $url -Headers $logHeaders -Method POST -Body $checkDataSelection -WebSession $websession
				# Clone cached query and update selection
				$data = $baseQuery.data.PSObject.Copy()
				$data.dataSelection.desired = $dataSelectionJson.dataSelection.actual
				$data.maxRecords = 1

				$uid = $queryUid

				# Reserve query
				Invoke-WebRequest -Uri "${env:URL}/?{`"request`":`"reserve`",`"uid`":$uid}" -Headers $logHeaders -Method GET -WebSession $websession | Out-Null
				Start-Sleep -Milliseconds 200

				# Save query
				$saveRequest = [ordered]@{
					request = "save"
					uid     = $uid
					mandator = $data.mandator.uid
					data  = [ordered]@{
						streamType = $data.streamType
						uid        = $uid
						enabled    = $data.enabled
						name       = $data.name
						comment    = $data.comment
						mandator = $data.mandator.uid
						type = $data.type
						index = $data.index
						indexAttributeName = $data.indexAttributeName
						aspectAttribute = $data.aspectAttribute
						sequenceType = $data.sequenceType
						hideSummary = $data.hideSummary
						highlightCppAttr = $data.highlightCppAttr
						dataSelection = $data.dataSelection
						columns = $data.columns
						maxRecords = $data.maxRecords
						maxSearchDepth = $data.maxSearchDepth
						maxRecordsWarning = $data.maxRecordsWarning
						maxRecordsLimit = $data.maxRecordsLimit
						adoptSimulationDataSelection = $data.adoptSimulationDataSelection
						extractTemplate = $data.extractTemplate
						includeDdcEnabled = $data.includeDdcEnabled
						execute = $false
						parameter = ""
					}
				}
				
				
				$jsonBody = $saveRequest | ConvertTo-Json -Depth 15 -Compress
				Invoke-RestMethod -Uri $url -Headers $logHeaders -Method POST -Body $jsonBody -WebSession $websession | Out-Null

				# Execute query
				Start-Sleep -Milliseconds 200
				$executeQuery = '{"request":"executeQuery","uid":' + $uid + ',"type":"query","data":{}}'
				$response = Invoke-RestMethod -Uri $url -Headers $logHeaders -Method POST -Body $executeQuery -WebSession $websession

				$getQueryResult = '{"request":"getQueryResults","uid":' + $uid + ',"data":{"resultId":' + $response.resultId + '}}'
				# Unreserve
				Start-Sleep -Milliseconds 200
				Invoke-WebRequest -Uri "${env:URL}/?{`"request`":`"unreserve`",`"uid`":$uid}" -Headers $logHeaders -Method GET -WebSession $websession | Out-Null

				# Poll until query finishes
				$logHeaders['Referer'] = "${env:URL}/investigation/queryResult/$($data.mandator.uid)/$uid/$($response.resultId)"

				do {
					Start-Sleep -Milliseconds 500
					$queryJson = Invoke-RestMethod -Uri $url -Headers $logHeaders -Method POST -Body $getQueryResult -WebSession $websession
				} while ($queryJson.running -eq "true")
				
				$oldIndexUrid = $indexUrid
			}
			
		# Extract index searched depending on query name
			switch ($queryName) {
				
				{ $_ -in 'Case Management PAN History 90 Days Acquiring Side', 'PAN Hyperlink', 'Case Management SMS Customer', 'Case Management PAN History 90 Days' } {
					if ($queryJson.queryResult.tableContent -and
						$queryJson.queryResult.tableContent.Count -gt 0 -and
						$queryJson.queryResult.tableContent[0].Count -gt 0 -and
						$queryJson.queryResult.tableContent[0][0]) {

						$indexSearched = $queryJson.queryResult.tableContent[0][0]
						
						if ($indexSearched.ToString().Length -ge 12) {
							# Mask PAN
							$indexSearchedStr = $indexSearched.ToString()
							$indexSearchedStr = $indexSearchedStr.Substring(0, 6) + ('*' * 6) + $indexSearchedStr.Substring(12)
							$indexSearched = $indexSearchedStr
						}
					} else {
						continue  # safely skip this row
					}
				}

				'Case Management PAN-Merchant ID 90 Days' {
					if ($queryJson.queryResult.tableContent -and
						$queryJson.queryResult.tableContent.Count -gt 0 -and
						$queryJson.queryResult.tableContent[0].Count -gt 2 -and
						$queryJson.queryResult.tableContent[0][2]) {

						$indexSearched = $queryJson.queryResult.tableContent[0][2]
						
						if ($indexSearched.ToString().Length -ge 12) {
							# Mask PAN
							$indexSearchedStr = $indexSearched.ToString()
							$indexSearchedStr = $indexSearchedStr.Substring(0, 6) + ('*' * 6) + $indexSearchedStr.Substring(12)
							$indexSearched = $indexSearchedStr
						}
					} else {
						continue
					}
				}

				{ $_ -in 'Case Management Merchant ID History 90 Days', 'Merchant ID Hyperlink' } {
					if ($queryJson.queryResult.tableContent -and
						$queryJson.queryResult.tableContent.Count -gt 0 -and
						$queryJson.queryResult.tableContent[0].Count -gt 1 -and
						$queryJson.queryResult.tableContent[0][1]) {

						$indexSearched = $queryJson.queryResult.tableContent[0][1]
					} else {
						continue
					}
				}
				
				'Case Management TIN History 90 Days' {
					if ($queryJson.queryResult.tableContent -and
						$queryJson.queryResult.tableContent.Count -gt 0 -and
						$queryJson.queryResult.tableContent[0].Count -gt 3 -and
						$queryJson.queryResult.tableContent[0][3]) {

						$indexSearched = $queryJson.queryResult.tableContent[0][3]
					} else {
						continue
					}
				}

				default {
					$indexSearched = ''
				}
			}
			
			if (($cleanRow[5] -match "index value urid=n/a") -or ($indexSearched -match "&#40;&#41;")) {
				$indexSearched = ""
			}


            # Build object
            $props = [PSCustomObject]@{
                Instance        = $cleanRow[0]
                Timestamp       = ([DateTime]::UnixEpoch.AddTicks([int64]$cleanRow[1] * 10)).ToLocalTime()
                Log             = $cleanRow[2]
                ID              = $cleanRow[3]
                User            = $cleanRow[4]
                'Query Name'    = $queryName
                'Index searched'= $indexSearched
                Message         = $cleanRow[5]
                Comment         = $cleanRow[6]
            }

            $results += $props
			$elapsed.Stop()
			$totalTimeMs += $elapsed.ElapsedMilliseconds
			$totalRecords++
        }
    }

    # Batch write to CSV once per interval
    if ($results.Count -gt 0) {
        $results | Export-Csv -Path $csvPath -NoTypeInformation -Append -Encoding UTF8
        $results = @()
		$avgTime = [math]::Round($totalTimeMs / $totalRecords, 2)
		$periodStart =  [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1970-01-01').AddSeconds($start)).ToString("MMM dd yyyy HH:mm:ss")
		$periodEnd = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1970-01-01').AddSeconds($end)).ToString("MMM dd yyyy HH:mm:ss")
		Write-Host "Period: $periodStart to $periodEnd"
		Write-Host "Processed $totalRecords records in $totalTimeMs ms (avg $avgTime ms per record)"
		Write-Host
    }

    # Show progress once we pass midnight
    if ($end -ge $currentMidnight) {
        $dayNumber   = [math]::Ceiling(($currentMidnight - $unixStart) / 86400)
        $currentDate = Get-Date -UnixTimeSeconds $currentMidnight -Format "yyyy-MM-dd"
        Write-Host "Processed day $dayNumber of $totalDays ($currentDate)"
		Write-Host
        $currentMidnight += 86400
    }
}

# Flush remaining results
if ($results.Count -gt 0) {
    $results | Export-Csv -Path $csvPath -NoTypeInformation -Append -Encoding UTF8
    $results = @()
}
