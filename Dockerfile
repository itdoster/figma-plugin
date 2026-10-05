# Ретранслятор WebSocket между MCP-сервером и плагином Figma (src/socket.ts).
# MCP-сервер в контейнер не кладём: его запускает Claude Code по stdio, а set_image_fill читает файлы с диска хоста.
FROM oven/bun:1-alpine

WORKDIR /app

# socket.ts зависит только от встроенного API Bun, зависимости из package.json ему не нужны
COPY src/socket.ts ./socket.ts

ENV PORT=3055
EXPOSE 3055

CMD ["bun", "socket.ts"]
