<#
MIT License
Copyright (c) 2025 I-SE7EN-I
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

$host.UI.RawUI.BackgroundColor = "Black"
$host.UI.RawUI.ForegroundColor = "White"
Clear-Host

function Get-Time {
	param (
		[string]$message
	)
	$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	Write-Host "[$timestamp] $message"
}

#Find Header And Data
function FHAD {
	param (
		#Default values for Header if none are provided.
		[Parameter(Mandatory = $true)][string]$x,
		[Parameter(Mandatory = $true)][string]$y,
		[Parameter(Mandatory = $true)]$ReceivedBytes
	)
	
	#Define Headers
	#Finding the Header
	$DataByteHeader = [byte[]]@("0x$x", "0x$y")
	$DataByteHeaderString = -join ($DataByteHeader | ForEach-Object { $_.ToString("X2") })

	#Finding the Header Index
	for ($i = 0; $i -lt $ReceivedBytes.Length - 2; $i++) {
		# Get the 2-byte string at the current position
		$currentBytes = -join ($ReceivedBytes[$i..($i + 1)] | ForEach-Object { $_.ToString("X2") })
		if ($currentBytes -eq $DataByteHeaderString) {
			$DataByteIndex = $i + $DataByteHeader.length
			$DataBytes = $receivedBytes[$DataByteIndex]
			$z = ($DataBytes | ForEach-Object { $_.ToString("X2") }) -join '-'
			break
		}
	}

	#Finding the Unit Data
	$DataLength = [int]"0x$z"
	$DataHeader = [byte[]]@("0x$x", "0x$y", "0x$z")
	$DataHeaderString = -join ($DataHeader | ForEach-Object { $_.ToString("X2") })
	for ($i = 0; $i -lt $ReceivedBytes.Length - 1; $i++) {
		# Get the 3-byte string at the current position
		$currentBytes = -join ($ReceivedBytes[$i..($i + 2)] | ForEach-Object { $_.ToString("X2") })
		if ($currentBytes -eq $DataHeaderString) {
			$unitDataIndex = $i + $DataHeader.length
			$unitDataBytes = $receivedBytes[$unitDataIndex..($unitDataIndex + ($DataLength - 1) )]
			$DataModel = ($unitDataBytes | ForEach-Object { $_.ToString("X2") }) -join '-'
			#Turn the byte array to required format
			$unitDataArray = $DataModel -split '-' | ForEach-Object { [Convert]::ToByte($_, 16) }
			$unitDataText = [System.Text.Encoding]::ASCII.GetString($unitDataArray)
			$unitDataIp = ($unitDataBytes | ForEach-Object { $_.ToString() }) -join '.'
			return @{
				Text  = $unitDataText
				Bytes = $DataModel
				Int   = $unitDataIp
			}
			break
		}
	}
}

function Start-Ubi-Discovery {

	$discoveredDevices = @()
	$filteredDevices = @()
	$outputChoice = ""

	$continue = $true
	while ($continue) {
		$userinput = Read-Host "`nHow would you like your output displayed? `n[1] In 'Script' `n[2] In 'Graph' `n[3] In 'Text Document' `n[4] In 'Excel Document' `n[5] In 'Both' `n`n"

		switch ($userinput) {
			"1" { $outputChoice = "script"; $continue = $false }
			""  { $outputChoice = "script"; $continue = $false }
			"2" { $outputChoice = "graph"; $continue = $false }
			"3" { $outputChoice = "textdocument"; $continue = $false }
			"4" { $outputChoice = "exceldocument"; $continue = $false }
			"5" { $outputChoice = "both"; $continue = $false }
			default { Write-Host "Unknown command" }
		}
	}

	# Define the broadcast address and the port for discovery
	$broadcastAddress = "255.255.255.255"
	$ports = @(10001) #Ports for Ubiquiti here

	# Create a UDP client
	$udpClient = New-Object System.Net.Sockets.UdpClient
	$udpClient.EnableBroadcast = $true

	# Define the discovery messages

	$discoveryMessages = @{
		"10001-Ubiquiti1" = [byte[]](0x01, 0x00, 0x00, 0x00)   # Ubiquiti Old Message
	}

	# Function to log messages with timestamp

	# Send the discovery messages
	foreach ($port in $ports) {
		$messageKey = "$port-Ubiquiti1"
		if ($discoveryMessages.ContainsKey($messageKey)) {
			$message = $discoveryMessages[$messageKey]
			Get-Time "Sending discovery message to port $port (Ubiquiti)..."
			$udpClient.Send($message, $message.Length, $broadcastAddress, $port) > $null
		}
	}

	Write-Host "-Listening for responses and calculating data...Please wait..."

	# Listen for responses
	$endPoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)

	# Set the timeout for receiving responses
	$udpClient.Client.ReceiveTimeout = 5000  # Increase the timeout to 5 seconds

	try {
		while ($true) {
			$receivedBytes = $udpClient.Receive([ref]$endPoint)
			$rawData = [System.BitConverter]::ToString($receivedBytes)
			$discoveredDevices += $rawData
		}
	}
	catch {
	# Close the UDP client
	$udpClient.Close()
		try {
			#Filters Raw Data Received
			$discoveredDevicesUnique = $discoveredDevices | Select-Object -Unique
			$discoveredDevicesUnique | ForEach-Object {

				# Determine if the response is from a Ubiquiti or Cambium device
				if ($receivedBytes.Length -ge 11) {
					if ($receivedBytes[0] -eq 0x01) {
						# Parse Ubiquiti response
						try {
							$receivedBytes = $_ -split '-' | ForEach-Object { [Convert]::ToByte($_, 16) }
						
							try {
								#Find the Model with Header
								$result = FHAD -x "0C" -y "00" -ReceivedBytes $receivedBytes
								$unitModelText = $result.Text
							}
							catch {
								$unitModelText = ""
							}
							
							try {
								#Find the Firmware with Header
								$result = FHAD -x "03" -y "00" -ReceivedBytes $receivedBytes
								$unitFirmwareText = $result.Text
							}
							catch {
								$unitFirmwareText = ""
							}

							try {
								#Find the Mac with Header
								$result = FHAD -x "02" -y "00" -ReceivedBytes $receivedBytes
								$mac1Address = (($result.Bytes -split '\-') | Select-Object -First 6) -join ':'
							}
							catch {
								$mac1Address = ""
							}

							try {
								#Find the IP with Header
								$result = FHAD -x "02" -y "00" -ReceivedBytes $receivedBytes
								$wanIpAddress = (($result.Int -split '\.') | Select-Object -Last 4) -join '.'
							}
							catch {
								$wanIpAddress = ""
							}
							
							try {
								#Find the Name with Header
								$result = FHAD -x "0B" -y "00" -ReceivedBytes $receivedBytes
								$unitNameText = $result.Text
							}
							catch {
								$unitNameText = ""
							}

							try {
								#Find the PTP with Header
								$result = FHAD -x "0D" -y "00" -ReceivedBytes $receivedBytes
								$ptpNameText = $result.Text
							}
							catch {
								$ptpNameText = ""
							}

							$filteredDevices += [pscustomobject]@{PTP = "$ptpNameText"; Name = "$unitNameText"; IP_Address = "$wanIpAddress"; Mac_Address = "$mac1Address"; Model = "$unitModelText"; Firmware = "$unitFirmwareText" }
							$unitNameText = ""
							$wanIpAddress = ""
							$mac1Address = ""
							$ptpNameText = ""
							$unitModelText = ""
							$unitFirmwareText = ""

						}
						catch {
							Write-Host "-Failed to parse Ubiquiti response: $_"
						}
					}
					elseif ($receivedBytes[0] -ne 0xFF -and $receivedBytes[0] -ne 0x01) {
						Write-Host "-Recieved Response from unkown device"
					}
				}
				else {
					Write-Host "-Received response with insufficient length: $($receivedBytes.Length) bytes"
				}
			}
		}
		catch {
			Write-Host "-Discovery Incomplete"
			Get-Time "`n"
		}
		$discoveredCount = $discoveredDevicesUnique.count
		Write-Host "-Discovery Complete"
		Write-Host "-Devices found: $discoveredCount"
		Get-Time "`n"

		if ($outputChoice -ne "graph") {
			$filteredDevices = $filteredDevices | Sort-Object Name
			$filteredDevices | ForEach-Object {

				$unitName = $_.Name
				$ipAddress = $_.IP_Address
				$macAddress = $_.Mac_Address
				$ptpName = $_.PTP
				$model = $_.Model
				$firmware = $_.Firmware

				Write-Output "------------------------------"
				Write-Output "-Unit Name:      $unitName"
				Write-Output "-Wan Ip Address: $ipAddress"
				Write-Output "-Mac Address:    $macAddress"
				Write-Output "-Connected Ptp:  $ptpName"
				Write-Output "-Unit Model:     $model"
				Write-Output "-Unit Firmware:  $firmware"
				Write-Output "------------------------------"
			}		
		}

		if ($outputChoice -eq "graph") {
			$filteredDevices | Out-GridView
		}

		if ($outputChoice -eq "textdocument" -or $outputChoice -eq "both") {
			try {
				$filteredDevices = $filteredDevices | Sort-Object Name

				# Path to the output text file
				$fileName = Read-Host "What would you like to name the Text document?`n"
				$currentDirectory = Get-Location
				$datetime = Get-Date
				$currentDate = Get-Date -Format "MM-dd-yy--HH-mm-ss"
				$outputFilePath = "$currentDirectory\$fileName $currentDate.txt"

				# Clear existing content in the file if it exists
				Clear-Content -Path $outputFilePath -ErrorAction Ignore
				Add-Content -Path $outputFilePath -Value "$datetime"
				Add-Content -Path $outputFilePath -Value "-Devices found: $discoveredCount`n"

				$filteredDevices | ForEach-Object {

					$unitName = $_.Name
					$ipAddress = $_.IP_Address
					$macAddress = $_.Mac_Address
					$ptpName = $_.PTP
					$model = $_.Model
					$firmware = $_.Firmware

					Add-Content -Path $outputFilePath -Value "------------------------------"
					Add-Content -Path $outputFilePath -Value "-Unit Name:      $unitName"
					Add-Content -Path $outputFilePath -Value "-Wan Ip Address: $ipAddress"
					Add-Content -Path $outputFilePath -Value "-Mac Address:    $macAddress"
					Add-Content -Path $outputFilePath -Value "-Connected Ptp:  $ptpName"
					Add-Content -Path $outputFilePath -Value "-Unit Model:     $model"
					Add-Content -Path $outputFilePath -Value "-Unit Firmware:  $firmware"
					Add-Content -Path $outputFilePath -Value "------------------------------"
				} 
			} catch {
				Write-Host "Could not save Text File."
			}		
		}
		if ($outputChoice -eq "exceldocument" -or $outputChoice -eq "both") {
			try {
				$filteredDevices = $filteredDevices | Sort-Object PTP
				$fileName = Read-Host "What would you like to name the Excel document?`n"
				$currentDirectory = Get-Location
				$currentDate = Get-Date -Format "MM-dd-yy--HH-mm-ss"
				$filteredDevices | Export-Csv -Path "$currentDirectory\$fileName $currentDate.csv" -NoTypeInformation
			} catch {
				Write-Host "Could not save Excel Document."
			}
		}
	}
}

function Start-Cam-Discovery {
	param (
		[int]$TimeoutSeconds = 60 # Default timeout of 60 seconds
	)

	$discoveredDevices = @()
	$filteredDevices = @()
	$outputChoice = ""

	$continue = $true
	while ($continue) {
		$userinput = Read-Host "`nHow would you like your output displayed? `n[1] In 'Script' `n[2] In 'Graph' `n[3] In 'Text Document' `n[4] In 'Excel Document'`n`n"

		switch ($userinput) {
			"1" { $outputChoice = "script"; $continue = $false }
			""  { $outputChoice = "script"; $continue = $false }
			"2" { $outputChoice = "graph"; $continue = $false }
			"3" { $outputChoice = "textdocument"; $continue = $false }
			"4" { $outputChoice = "exceldocument"; $continue = $false }
			"5" { $outputChoice = "both"; $continue = $false }
			default { Write-Host "Unknown command" }
		}
	}

	# Create a UDP client
	$udpClient = New-Object System.Net.Sockets.UdpClient(5678)

	# Function to log messages with timestamp

	Write-Host "-Listening for responses and calculating data...Please wait at least 60 seconds..."

	# Listen for responses
	$endPoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)

	# Set the timeout for receiving responses
	$udpClient.Client.ReceiveTimeout = 59000  # Increase the timeout to 5 seconds
	$startTime = Get-Date
	while ($true) {
		# Check if timeout has elapsed
		if ((Get-Date) - $startTime -gt (New-TimeSpan -Seconds $TimeoutSeconds)) {
			Write-Host "Discovery timeout reached. Exiting..."
			break
		}

		try {
			# Attempt to receive data
			$receivedBytes = $udpClient.Receive([ref]$endPoint)
			$rawData = [System.BitConverter]::ToString($receivedBytes)
			$discoveredDevices += $rawData
		}
		catch {
			# Handle receive timeout or other errors
			break
		}
	}

	# Close the UDP client
	$udpClient.Close()
	try {
		#Filters Raw Data Received	
		$discoveredDevicesUnique = $discoveredDevices | Select-Object -Unique	
		$discoveredDevicesUnique | ForEach-Object {

			# Determine if the response is from a Cambuim or Cambium device
			if ($receivedBytes.Length -ge 11) {
				if ($receivedBytes[0] -eq 0x00) {
					# Parse Ubiquiti response
					try {
						$receivedBytes = $_ -split '-' | ForEach-Object { [Convert]::ToByte($_, 16) }
					
						try {
							#Find the Model with Header
							$result = FHAD -x "08" -y "00" -ReceivedBytes $receivedBytes
							$unitModelText = $result.Text
						}
						catch {
							$unitModelText = ""
						}
						
						try {
							#Find the Firmware with Header
							$result = FHAD -x "07" -y "00" -ReceivedBytes $receivedBytes
							$unitFirmwareText = $result.Text
						}
						catch {
							$unitFirmwareText = ""
						}

						try {
							#Find the Mac with Header
							$result = FHAD -x "01" -y "00" -ReceivedBytes $receivedBytes
							$mac1Address = (($result.Bytes -split '\-') | Select-Object -First 6) -join ':'
						}
						catch {
							$mac1Address = ""
						}

						try {
							$wanipAddress = $endPoint.Address.ToString()
						}
						catch {
							$wanIpAddress = ""
						}
						
						try {
							#Find the Name with Header
							$result = FHAD -x "05" -y "00" -ReceivedBytes $receivedBytes
							$unitNameText = $result.Text
						}
						catch {
							$unitNameText = ""
						}

						try {
							#Find the PTP with Header
							$result = FHAD -x "0D" -y "00" -ReceivedBytes $receivedBytes
							$ptpNameText = $result.Text
						}
						catch {
							$ptpNameText = ""
						}

						$filteredDevices += [pscustomobject]@{Name = "$unitNameText"; IP_Address = "$wanIpAddress"; Mac_Address = "$mac1Address"; PTP = "$ptpNameText"; Model = "$unitModelText"; Firmware = "$unitFirmwareText" }
						$unitNameText = ""
						$wanIpAddress = ""
						$mac1Address = ""
						$ptpNameText = ""
						$unitModelText = ""
						$unitFirmwareText = ""

					}
					catch {
						Write-Host "-Failed to parse Cambium response: $_"
					}
				}
				elseif ($receivedBytes[0] -ne 0xFF -and $receivedBytes[0] -ne 0x01) {
					Write-Host "-Recieved Response from unkown device"
				}
			}
			elseif ($receivedBytes[0] -ne 0xff -and $receivedBytes[0] -ne 0x01) {
				Write-Host "-Recieved Response from unkown device"
				Write-Host "$discoveredDevicesUnique"
			}
		}
		else {
			Write-Host "-Received response with insufficient length: $($receivedBytes.Length) bytes"
		}
	}
	catch {
		# Close the UDP client
		Write-Host "-Discovery Incomplete"
		Get-Time "`n"
	}
	$discoveredCount = $discoveredDevicesUnique.count
	Write-Host "-Discovery Complete"
	Write-Host "-Devices found: $discoveredCount"
	Get-Time "`n"

		if ($outputChoice -ne "graph") {
			$filteredDevices = $filteredDevices | Sort-Object Name
			$filteredDevices | ForEach-Object {

				$unitName = $_.Name
				$ipAddress = $_.IP_Address
				$macAddress = $_.Mac_Address
				$ptpName = $_.PTP
				$model = $_.Model
				$firmware = $_.Firmware

				Write-Output "------------------------------"
				Write-Output "-Unit Name:      $unitName"
				Write-Output "-Wan Ip Address: $ipAddress"
				Write-Output "-Mac Address:    $macAddress"
				Write-Output "-Connected Ptp:  $ptpName"
				Write-Output "-Unit Model:     $model"
				Write-Output "-Unit Firmware:  $firmware"
				Write-Output "------------------------------"
			}		
		}

		if ($outputChoice -eq "graph") {
			$filteredDevices | Out-GridView
		}

		if ($outputChoice -eq "textdocument" -or $outputChoice -eq "both") {
			try {
				$filteredDevices = $filteredDevices | Sort-Object Name

				# Path to the output text file
				$fileName = Read-Host "What would you like to name the Text document?`n"
				$currentDirectory = Get-Location
				$datetime = Get-Date
				$currentDate = Get-Date -Format "MM-dd-yy--HH-mm-ss"
				$outputFilePath = "$currentDirectory\$fileName $currentDate.txt"

				# Clear existing content in the file if it exists
				Clear-Content -Path $outputFilePath -ErrorAction Ignore
				Add-Content -Path $outputFilePath -Value "$datetime"
				Add-Content -Path $outputFilePath -Value "-Devices found: $discoveredCount`n"

				$filteredDevices | ForEach-Object {

					$unitName = $_.Name
					$ipAddress = $_.IP_Address
					$macAddress = $_.Mac_Address
					$ptpName = $_.PTP
					$model = $_.Model
					$firmware = $_.Firmware

					Add-Content -Path $outputFilePath -Value "------------------------------"
					Add-Content -Path $outputFilePath -Value "-Unit Name:      $unitName"
					Add-Content -Path $outputFilePath -Value "-Wan Ip Address: $ipAddress"
					Add-Content -Path $outputFilePath -Value "-Mac Address:    $macAddress"
					Add-Content -Path $outputFilePath -Value "-Connected Ptp:  $ptpName"
					Add-Content -Path $outputFilePath -Value "-Unit Model:     $model"
					Add-Content -Path $outputFilePath -Value "-Unit Firmware:  $firmware"
					Add-Content -Path $outputFilePath -Value "------------------------------"
				} 
			} catch {
				Write-Host "Could not save Text File."
			}		
		}
		if ($outputChoice -eq "exceldocument" -or $outputChoice -eq "both") {
			try {
				$filteredDevices = $filteredDevices | Sort-Object PTP
				$fileName = Read-Host "What would you like to name the Excel document?`n"
				$currentDirectory = Get-Location
				$currentDate = Get-Date -Format "MM-dd-yy--HH-mm-ss"
				$filteredDevices | Export-Csv -Path "$currentDirectory\$fileName $currentDate.csv" -NoTypeInformation
			} catch {
				Write-Host "Could not save Excel Document."
			}
		}
}

function Start-SSH {
	# Define the IP and Username
	$ipAddress = Read-Host "`nEnter IP Address"
	$sshUser = Read-Host "`nWhat is the Username"

	# Create the SSH tunnel
	Write-Host "Starting the ssh tunnel. Type EXIT to close the tunnel when you are done."
	Start-Sleep -Seconds 3

	ssh -L 17114:localhost:443 $sshUser@$ipAddress

	# Pause at the end
	Read-Host -Prompt "Press Enter to exit SSH"
}

# Call to Set IP Address
function SIP {
	param (
		[Parameter(Mandatory = $true)][string]$newIP,
		[Parameter(Mandatory = $true)][string]$newSubnet,
		[Parameter(Mandatory = $true)][string]$newGateway,
		[Parameter(Mandatory = $true)][string]$ifIndex,
		$DNS = "1.0.0.1,8.8.4.4"
	)

	$ipFamily = "IPv4"
	Set-NetIPInterface -InterfaceIndex $ifIndex -Dhcp Disabled

	try {
		# Check if the desired IP is already set
		$existingIP = Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily $ipFamily -ErrorAction SilentlyContinue |
		Where-Object { $_.IPAddress -eq $newIP }
		if ($existingIP) {
			Write-Host "IP address $newIP is already assigned to the selected adapter."
		}
		else {
			# Remove existing IP addresses
			$existingIPAddresses = Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily $ipFamily -ErrorAction SilentlyContinue
			if ($existingIPAddresses) {
				Write-Host "Removing existing IP addresses..."
				$existingIPAddresses | ForEach-Object {
					Remove-NetIPAddress -IPAddress $_.IPAddress -InterfaceIndex $ifIndex -Confirm:$false -ErrorAction SilentlyContinue
					$routeExists = Get-NetRoute -InterfaceIndex $ifIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue
					if ($routeExists) {
						try {
							Remove-NetRoute -InterfaceIndex $ifIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction Stop -Confirm:$false
							Write-Host "Route removed successfully."
						}
						catch {
							Write-Host "Failed to remove route: $_"
						}
					}
					else {
						Write-Host "No route to remove. Skipping..."
					}
				}
			}

			# Wait for the system to process changes
			while ((Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily $ipFamily -ErrorAction SilentlyContinue)) {
				Start-Sleep -Seconds 1
			}

			# Verify that no IP addresses remain
			$clearedIPs = Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily $ipFamily -ErrorAction SilentlyContinue
			if ($clearedIPs) {
				Write-Host "Failed to remove existing IP addresses. Please check adapter state."
				return
			}

			# Set the new static IP address
			New-NetIPAddress -InterfaceIndex $ifIndex -IPAddress $newIP -PrefixLength $newSubnet -DefaultGateway $newGateway -ErrorAction Stop
			Write-Host "Assigned IP address: $newIP/$newSubnet"
		}

		# Set DNS servers
		Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses $DNS
		Write-Host "Set DNS servers: $DNS"

		# Confirm settings
		$currentIpInfo = Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4
		$currentGateway = (Get-NetRoute -InterfaceIndex $ifIndex -DestinationPrefix "0.0.0.0/0").NextHop
		$currentDNS = (Get-DnsClientServerAddress -InterfaceIndex $ifIndex).ServerAddresses -join ", "

		Write-Host "`nSettings applied successfully!"
		Write-Host "IP=$($currentIpInfo.IPAddress), Gateway=$currentGateway, DNS=$currentDNS"
	}
 catch {
		Write-Host "`nFailed to set IP address: $_"
	}
}

# Set the IP Address of Machine
function Set-Ip {
# Check if running as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {

	$continue = $true

	while ($continue) {
		$adminChoice = ""
		$userinput = Read-Host "`nWould you like to restart in administration mode? (Required for the script to edit this machines IP)
		`n[1]No
		`n[2]Yes
		`n"

		switch ($userinput) {
			{ $_ -in "2", "y", "yes" } { $adminChoice = "yes"; $continue = $false }
			{ $_ -in "1", "n", "no", "" } { $adminChoice = "no"; $continue = $false }
			default { Write-Host "Unknown command" }
		}
	}
	# Relaunch the script with admin privileges  |  powershell = ps5  |  pwsh = ps7+
	if ($adminChoice -eq "yes") {
		Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
#		Start-Process pwsh -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
		exit
	}
	else {
		$continue = $true
		Clear-Host
	}
}

	# Show available network adapters with Out-GridView for selection
	$selectedAdapter = Get-NetAdapter | Out-GridView -Title "Select a Network Adapter" -PassThru
	if ($null -eq $selectedAdapter) {
		Write-Host "No adapter selected. Exiting..."
		return
	}
	$ifIndex = $selectedAdapter.IfIndex
	# Check if the adapter is connected
	$adapterStatus = (Get-NetAdapter -InterfaceIndex $ifIndex).Status
	if ($adapterStatus -ne "Up") {
		Write-Host "`nThe adapter is not connected. Please connect the Ethernet cable before proceeding."
		return
	}

	#Get current Index Info
	try {
		$currentIpInfo = Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4
		$currentGateway = ""
		try {
			$route = Get-NetRoute -InterfaceIndex $ifIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue
			if ($null -ne $route) {
				$currentGateway = $route.NextHop
			}
			else {
				Write-Host "`nNo Gateway Detected"
			}
		}
		catch {
			Write-Host "`nAn error occurred while retrieving the gateway: $_`n"
		}
		$currentDNS = (Get-DnsClientServerAddress -InterfaceIndex $ifIndex).ServerAddresses -join ", "

		Write-Host "Current Ip Settings: IP=$($currentIpInfo.IPAddress), Gateway=$currentGateway, DNS=$currentDNS"
	}
	catch {
		Write-Host "`nError Occurred: $_"
	}

	# Ask the user if they want to apply custom, preset, or DHCP settings
	$option = Read-Host "What would you like to do?`n`n[1] Apply preset settings`n[2] Apply custom settings`n[3] Set to DHCP`n[4] Cancel`n`n"

	if ($option -eq '1') {

		# Load Presets.psd1
		$presetsFile = "$PSScriptRoot\IpPresets.psd1"
		if (-Not (Test-Path $presetsFile)) {
			Write-Host "Preset file not found!"
			exit
		}

		$presets = Import-PowerShellDataFile -Path $presetsFile

		# Display menu dynamically
		Write-Host "`nSelect a Preset IP:"
		foreach ($key in ($presets.Keys | Sort-Object {[int]$_})) {
			Write-Host "[$key] $($presets[$key].IP) Gateway ($($presets[$key].Name))"
		}
		Write-Host "[Any Other] Cancel"

		$option2 = Read-Host "`nWhat Preset IP would you like?"

		# Apply selected preset if valid
		if ($presets.ContainsKey($option2)) {
			$selectedPreset = $presets[$option2]
			SIP -newIP $selectedPreset.IP -newSubnet $selectedPreset.Subnet -newGateway $selectedPreset.Gateway -ifIndex $ifIndex
		} else {
			Write-Host "Operation canceled."
		}

	}
 elseif ($option -eq '2') {
		# Custom settings
		$newIP = Read-Host "Enter the static IP address"
		$newSubnet = Read-Host "Enter the subnet prefix length:`n[24] = .255`n[21] = .248`n[20] = .240`n"
		$newGateway = Read-Host "Enter the default gateway"
		$DNS = Read-Host "Enter the DNS servers (comma-separated)"
		SIP -newIP $newIP -newSubnet $newSubnet -newGateway $newGateway -DNS $DNS -ifIndex $ifIndex
	}
 elseif ($option -eq '3') {
		# Set to DHCP
		try {
			Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
			ForEach-Object {
				Remove-NetIPAddress -IPAddress $_.IPAddress -InterfaceIndex $ifIndex -Confirm:$false -ErrorAction SilentlyContinue
			}
		}
		catch {
			Write-Host "Looks like DHCP is already set."
			return
		}
		try {
			Get-NetRoute -InterfaceIndex $ifIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | 
			ForEach-Object {
				Remove-NetRoute -InterfaceIndex $ifIndex -DestinationPrefix $_.DestinationPrefix -Confirm:$false -ErrorAction SilentlyContinue
			}
		}
		catch {
			Write-Host "Looks like DHCP is already set."
			return
		}
		try {
			Write-Host "Setting DHCP"
			Set-NetIPInterface -InterfaceIndex $ifIndex -Dhcp Enabled
			Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses "1.0.0.1,8.8.4.4"
			Write-Host "IP Releasing"
			ipconfig /release >$null
			Write-Host "IP Renewing"
			ipconfig /renew >$null
			Write-Host "Set to DHCP mode."
			try {
				#Get Set Info
				$currentIpInfo = Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4
				$currentGateway = ""
				try {
					$route = Get-NetRoute -InterfaceIndex $ifIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue
					if ($null -ne $route) {
						$currentGateway = $route.NextHop
					}
					else {
						Write-Host "`nNo Gateway Detected"
					}
				}
				catch {
					Write-Host "`nAn error occurred while retrieving the gateway: $_`n"
				}
				$currentDNS = (Get-DnsClientServerAddress -InterfaceIndex $ifIndex).ServerAddresses -join ", "

				Write-Host "Preset settings applied: IP=$($currentIpInfo.IPAddress), Gateway=$currentGateway, DNS=$currentDNS"
			}
			catch {
				Write-Host "`nError Occurred: $_"
			}
		}
		catch {
			Write-Host "An Error has occurred: $_"
		}
	}
 else {
		Write-Host "Operation canceled."
	}
}

# Main Menu
$continue = $true
while ($continue) {
	$userinput = Read-Host "`nWhat would you like to do? `n[1] 'Scan (Ubiquiti)' `n[2] 'Scan (Cambium)' `n[3] 'Tcp-Ip Setup' `n[4] 'SSH' `n[5] 'Exit'`n`n"

	switch ($userinput) {
		{ $_ -in "1", "" } { Start-Ubi-Discovery }
		{ $_ -in "2" } { Start-Cam-Discovery }
		{ $_ -in "tcpip", "tc", "3" } { Set-Ip }
		{ $_ -in "ssh", "ss", "4" } { Start-SSH }
		{ $_ -in "exit", "ex", "5" } { $continue = $false }
		default { Write-Host "Unknown command" }
	}
}

Write-Host "`n-Exiting Script...`n"
Start-Sleep -Seconds 3
