<#
.SYNOPSIS
    Docker Minecraft Bedrock Server Player Notifications to Gotify
.DESCRIPTION
    This script monitors the Docker logs of a specified Minecraft Bedrock container and sends new player connection and disconnection events to a Gotify webhook.
    The Gotify URL, API token and container name should be set as environment variables.

.PARAMETER MGRAM_GOTIFY_TOKEN
    The Gotify API token for authentication. Set as an environment variable.

.PARAMETER MGRAM_GOTIFY_URL
    The URL of the Gotify server where the webhook messages will be sent. Set as an environment variable.

.PARAMETER MGRAM_CONTAINER_NAME
    The name of the Docker container to retrieve logs from. Set as an environment variable.
#>

# Function to send a message to Gotify with Markdown formatting
function Send-GotifyMessage {
    param (
        [string]$message
    )

    $payload = @{
        "title"      = "Minecraft Server"
        "message"    = $message
        "priority"   = 5
        "extras" = @{
          "client::display" = @{
              "contentType" = "text/markdown"
          }
        }
    }

    try {
        $sendGotify = Invoke-WebRequest -Uri "$($gotifyUrl)/message" -Method Post -ContentType "application/json" -Body (ConvertTo-Json -Compress -Depth 5 -InputObject $payload) -Headers @{ "X-Gotify-Key" = $gotifyToken } -ErrorAction Stop

        if ($($sendGotify | Select-Object -Expand StatusCode) -eq "200") {
            Write-Verbose -Message "Message sent successfully: $message, $($sendGotify | Select-Object StatusCode,StatusDescription)" -Verbose
            Start-Sleep -Seconds 1
        } else {
            Write-Warning -Message "Failed to send message: $message, $($sendGotify | Select-Object StatusCode,StatusDescription)" -Verbose
            Start-Sleep -Seconds 1
        }
    } catch {
        Write-Warning -Message "Error sending message: $_"
    }
}

# Retrieve the Gotify API token, Gotify URL, and container name from environment variables
$gotifyToken = $env:MGRAM_GOTIFY_TOKEN
$gotifyUrl = $env:MGRAM_GOTIFY_URL
$containerName = $env:MGRAM_CONTAINER_NAME

Write-Verbose -Message "Listening to Container: $containerName" -Verbose
Write-Verbose -Message "Using Gotify URL: $($gotifyUrl)/message" -Verbose

# Initialize an array to store previous log entries
$previousEntries = @()

# Continuously monitor Docker logs and send new events to the Gotify webhook
while ($true) {
    Start-Sleep -Seconds 5
    # Retrieve the Docker logs of the specified container
    $dockerLogs = docker logs --tail=128 $containerName

    # Filter new log entries matching the specified patterns
    $newEntries = $dockerLogs | Where-Object { $_ -match "(Player connected|Player disconnected): (.+), xuid: (\d+).*" }

    # Process new entries and send them as Gotify webhooks
    foreach ($entry in $newEntries) {
        # Check if the entry has been previously sent
        if ($previousEntries -notcontains $entry) {
            # Extract the player and xuid information from the log entry
            $player = $entry -replace "(Player connected|Player disconnected): (.+), xuid: (\d+).*", '$2'
            $xuid = $entry -replace "(Player connected|Player disconnected): (.+), xuid: (\d+).*", '$3'

            # Determine the message based on the log entry type with Markdown formatting
            if ($entry -match "Player connected") {
                $message = "Connected: **$($player.Substring(31))** `nxuid: $($xuid.Substring(31))"
            } else {
                $message = "Disconnected: **$($player.Substring(31))** `nxuid: $($xuid.Substring(31))"
            }

            # Send the message as a Gotify webhook
            Send-GotifyMessage -message $message

            # Add the entry to the list of previous entries
            $previousEntries += $entry
        }
    }
}
