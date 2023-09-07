# bedrock-docker-gotify

A Gotify Notification Service for Docker Minecraft Bedrock Servers.
Notifies upon Connection or Disconnection of Players. 
No Minecraft Plugins or Addons required. 

![Showing Connection Messages in Gotify](../main/gotify-notice.png)

## Requirements
- Minecraft Bedrock Server running in Docker
- Running Minecraft Logger Container with read access to Docker socket on the same host

## How to run
### Docker Compose
Define the environment variables:
 - ``` MGRAM_GOTIFY_URL "..." ``` Set to your Gotify URL (https://gotify-server.example.com)
 - ``` MGRAM_GOTIFY_TOKEN "..." ```  Set to your Gotify Application Token 
 - ``` MGRAM_CONTAINER_NAME "..." ``` Set the name of the Minecraft Bedrock container you want to monitor
 - Edit your docker compose file and add the notifier as a new service:

```yaml
bds-gotify-notifier:
    image: ghcr.io/gigigig/bedrock-docker-gotify:latest
    environment:
      MGRAM_GOTIFY_URL : "YOUR_GOTIFY_URL"
      MGRAM_GOTIFY_TOKEN: "YOUR_GOTIFY_URL"
      MGRAM_CONTAINER_NAME: "YOUR_BEDROCK_CONTAINER_NAME"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
```
See [docker-compose.yml](../main/docker-compose.yml) for a full example. 

### Build with Dockerfile
```Shell
git clone https://github.com/gigigig/bedrock-docker-gotify/
cd bedrock-docker-gotify/
docker build .
```



