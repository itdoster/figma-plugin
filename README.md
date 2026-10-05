# TalkToFigma — форк с `execute_code` и `set_image_fill`

Связка «Claude Code ↔ Figma»: агент читает и правит открытый в Figma файл через MCP. Форк
[grab/cursor-talk-to-figma-mcp](https://github.com/grab/cursor-talk-to-figma-mcp) (MIT), исходное
описание — [README.upstream.md](README.upstream.md).

## Что добавлено в форке

| Команда | Что делает |
|---|---|
| `execute_code` | выполняет произвольный JavaScript в плагине с полным Plugin API: шрифты, градиенты, обводки и тени текста, импорт компонентов библиотеки по ключу, перенос узлов, автолейаут |
| `set_image_fill` | берёт картинку с диска, передаёт в плагин и ставит её заливкой узла (`figma.createImage`) |

Плюс к этому:
- у плагина свой id `cursor-mcp-plugin-local` и имя **Cursor MCP Plugin LOCAL**. С id опубликованной версии
  Figma запускала Community-плагин вместо локального, и новые команды отвечали `Unknown command`;
- ретранслятор `src/socket.ts` поднимает TLS, только если заданы `SSL_KEY_PATH` и `SSL_CERT_PATH`, а без них
  работает обычным `ws://` на localhost.

## Как это устроено

Частей три, и все три должны работать одновременно:

```
Claude Code ──stdio──▶ MCP-сервер (dist/server.js) ──ws://localhost:3055──▶ ретранслятор (src/socket.ts) ◀──ws── плагин в Figma
```

- **MCP-сервер** запускает сам Claude Code — руками его стартовать не нужно.
- **Ретранслятор** запускаешь ты, он держит канал между сервером и плагином.
- **Плагин** работает внутри Figma Desktop. Без открытого файла с запущенным плагином агенту не к чему
  подключаться: серверного режима у плагинов Figma нет.

## Установка (один раз)

Нужны: [Bun](https://bun.sh), Node.js 18+, Figma Desktop, Claude Code.

**1. Bun**

```bash
# macOS / Linux
curl -fsSL https://bun.sh/install | bash
# Windows (PowerShell)
powershell -c "irm bun.sh/install.ps1 | iex"
```

**2. Репозиторий и зависимости**

```bash
git clone https://github.com/itdoster/figma-plugin.git
cd figma-plugin
bun install
```

Сборка `dist/` уже лежит в репозитории. Пересобирать (`bun run build`) нужно только после правки
`src/talk_to_figma_mcp/server.ts`.

**3. MCP в Claude Code**

Из папки репозитория:

```bash
# macOS / Linux
claude mcp add TalkToFigma --scope user -- node "$(pwd)/dist/server.js"
# Windows (PowerShell)
claude mcp add TalkToFigma --scope user -- node "$((Get-Location).Path)\dist\server.js"
```

Проверка — `claude mcp list` показывает `TalkToFigma`. Если Claude Code уже открыт, выполни в нём `/mcp`
→ TalkToFigma → reconnect.

**4. Плагин в Figma**

Figma Desktop → меню **Plugins → Development → Import plugin from manifest…** → выбрать
`src/cursor_mcp_plugin/manifest.json` из папки репозитория.

Импортируй именно **plugin**, не widget: на «Import widget» Figma отвечает ошибкой `manifest.containsWidget`.

## Запуск (каждый раз)

1. **Ретранслятор** — один из двух способов:

   - **Docker (рекомендуется)** — см. раздел [«Ретранслятор в Docker»](#ретранслятор-в-docker). Поднимается один раз
     и дальше стартует сам вместе с Docker, этот шаг можно пропускать.
   - **Вручную** — в отдельном терминале, из папки репозитория:

     ```bash
     bun socket
     ```

     Ждём строку `WebSocket server running on port 3055`. Терминал не закрывать.

2. **Плагин** — открыть нужный файл в Figma Desktop → **Plugins → Development → Cursor MCP Plugin LOCAL** →
   **Connect**. Плагин покажет `Connected to server in channel: <id>`. Id новый при каждом запуске.

3. **Claude Code** — отправь агенту этот id (например `Connected to server in channel: ilfyrl73`). Агент
   вызовет `join_channel` и проверит связь:

   ```
   execute_code("return figma.root.name")   →  имя открытого файла
   ```

## Ретранслятор в Docker

В контейнере живёт только ретранслятор `src/socket.ts`. MCP-сервер остаётся на хосте: его запускает Claude
Code по stdio, а `set_image_fill` читает картинки с диска хоста. Плагин работает в Figma Desktop.

Нужен Docker Desktop (macOS / Windows) или Docker Engine (Linux).

```bash
cd figma-plugin
docker compose up -d --build
```

Проверка:

```bash
docker logs figma-relay      # WebSocket server running on port 3055
```

Контейнер поднят с `restart: unless-stopped`: после перезагрузки он стартует сам, как только запустится Docker.
`bun socket` при этом запускать не нужно, а если он запущен, то займёт тот же порт, и контейнер не поднимется.

| Действие | Команда |
|---|---|
| остановить | `docker compose down` |
| пересобрать после правки `src/socket.ts` | `docker compose up -d --build` |

Порт менять нельзя: MCP-сервер на localhost всегда подключается к 3055.

## Если не работает

| Симптом | Причина и что делать |
|---|---|
| `Unknown command: execute_code` | запущен Community-плагин, а не локальный. Запускать **Cursor MCP Plugin LOCAL** из Development |
| `Request to Figma timed out` | плагин закрылся или Figma ушла в фон надолго. Перезапусти плагин и пришли новый id канала |
| плагин не подключается | ретранслятор не запущен (`docker ps` не показывает `figma-relay`, и `bun socket` не запущен), или порт 3055 занят другим процессом: `lsof -iTCP:3055` (macOS / Linux), `netstat -ano \| findstr 3055` (Windows) |
| `docker compose up` падает с `port is already allocated` | на 3055 уже работает `bun socket` — останови его |
| `manifest.containsWidget` | импортировал как widget. Нужно **Import plugin from manifest** |
| в Claude Code нет инструментов TalkToFigma | `/mcp` → reconnect. Проверь, что путь в `claude mcp get TalkToFigma` указывает на существующий `dist/server.js` |
| WSL на Windows: плагин не видит ретранслятор | в `src/socket.ts` раскомментировать `hostname: "0.0.0.0"` |

**Большие `execute_code`.** Длинный скрипт может оборвать связь с плагином, и тогда изменения не применятся
вовсе. Держи один вызов — один логический блок, после обрыва проверяй состояние файла, прежде чем повторять.

## Безопасность

`execute_code` выполняет любой код в открытом файле с правами того, кто запустил плагин, вплоть до удаления
страниц. Ретранслятор без авторизации: ключ — только id канала. На localhost это безопасно. Если
выносишь ретранслятор на общий сервер, открывай его только во внутреннюю сеть или VPN.

## Разработка

| Что правишь | Что сделать после |
|---|---|
| `src/talk_to_figma_mcp/server.ts` | `bun run build`, затем в Claude Code `/mcp` → reconnect |
| `src/cursor_mcp_plugin/code.js` или `ui.html` | закрыть и снова запустить плагин в Figma, сборка не нужна |
| `src/socket.ts` | перезапустить `bun socket` или `docker compose up -d --build` |

Новая команда добавляется в двух местах: инструмент в `server.ts` (`server.tool(...)` плюс имя в
типе `FigmaCommand`) и ветка `case` в `handleCommand` плагина `code.js`.
