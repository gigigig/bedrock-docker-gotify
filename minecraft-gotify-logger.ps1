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
# Hashtable to track pfid by xuid from spawn events
$playerPfids = @{}

# Regular expression pattern to extract player information
$entryPattern = [regex]'(?i)Player\s+(?<action>connected|disconnected):\s*(?<player>[^,]+),\s*xuid:\s*(?<xuid>\d+)(?:,\s*pfid:\s*(?<pfid>[0-9a-f]+))?'
# Regex for spawn events that include pfid
$spawnPattern = [regex]'(?i)Player Spawned:\s*(?<player>[^ ]+)\s+xuid:\s*(?<xuid>\d+),\s*pfid:\s*(?<pfid>[0-9a-f]+)'

# Continuously monitor Docker logs and send new events to the Gotify webhook
while ($true) {
    Start-Sleep -Seconds 5
    # Retrieve the Docker logs of the specified container
    $dockerLogs = docker logs --tail=128 $containerName

    # Filter new log entries matching the specified patterns
    $newEntries = $dockerLogs | Where-Object { $entryPattern.IsMatch($_) -or $spawnPattern.IsMatch($_) }

    # Process new entries and send them as Gotify webhooks
    foreach ($entry in $newEntries) {
        if ($previousEntries -contains $entry) { continue }

        # Handle spawn events to collect pfid information
        if ($spawnPattern.IsMatch($entry)) {
            $match = $spawnPattern.Match($entry)
            $xuid  = $match.Groups['xuid'].Value.Trim()
            $pfid  = $match.Groups['pfid'].Value.Trim()
            if ($xuid -and $pfid) { $playerPfids[$xuid] = $pfid }
            $previousEntries += $entry
            continue
        }

        # Extract player info from connect/disconnect logs
        $match   = $entryPattern.Match($entry)
        $player  = $match.Groups['player'].Value.Trim()
        $xuid    = $match.Groups['xuid'].Value.Trim()
        $action  = $match.Groups['action'].Value.ToLower()
        $pfid    = $match.Groups['pfid'].Value.Trim()

        if ($pfid) {
            $playerPfids[$xuid] = $pfid
        } elseif ($playerPfids.ContainsKey($xuid)) {
            $pfid = $playerPfids[$xuid]
        }

        # Determine the message based on the log entry type with Markdown formatting
        if ($action -eq 'connected') {
            $actionWord = 'Connected'
        } else {
            $actionWord = 'Disconnected'
        }

        $message = "${actionWord}: **$player** `nxuid: $xuid"
        if ($pfid) { $message += "`npfid: $pfid" }

        Send-GotifyMessage -message $message
        $previousEntries += $entry
    }
}