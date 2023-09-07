FROM alpine:latest

WORKDIR /app

RUN apk update && \
    apk add docker && \
    apk add powershell

ADD minecraft-gotify-logger.ps1 /app

CMD ["pwsh", "-f", "/app/minecraft-gotify-logger.ps1"]