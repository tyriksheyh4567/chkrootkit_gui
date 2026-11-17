# Codex, MCP и локальные инструкции

## Как Codex читает этот проект

При запуске из корня Codex подхватывает `AGENTS.md`. Файл `SKILLS.md` содержит
проектные режимы и должен быть прочитан перед изменением Flutter-кода. Если в
подкаталоге появится свой `AGENTS.md`, его правила дополняют корневые для этого
подкаталога.

## Подключение MCP в Codex CLI

Выполни из любого каталога:

```bash
codex mcp add openaiDeveloperDocs --url https://developers.openai.com/mcp
codex mcp list
```

Отключение:

```bash
codex mcp remove openaiDeveloperDocs
```

Эквивалентная запись в `~/.codex/config.toml`:

```toml
[mcp_servers.openaiDeveloperDocs]
url = "https://developers.openai.com/mcp"
```

Эта конфигурация общая для Codex CLI и IDE extension. MCP-сервер OpenAI Docs
предоставляет поиск и чтение документации; он не вызывает OpenAI API от имени
проекта.

## Локальный HTTP MCP-сервер (шаблон)

Для внутреннего сервера добавь отдельную запись в `~/.codex/config.toml`, не в
репозиторий:

```toml
[mcp_servers.my_local_docs]
url = "http://127.0.0.1:8787/mcp"
```

Перед подключением проверь endpoint и политику доступа. Секреты передавай через
переменные окружения или менеджер секретов, а не через git-файлы.

## MCP в portable plugin (не обязательно)

Если позже понадобится переносимый пакет навыков, структура может быть такой:

```text
.codex-plugin/plugin.json
.mcp.json
skills/<skill-name>/SKILL.md
```

`.mcp.json`:

```json
{
  "mcpServers": {
    "openai_docs": {
      "type": "http",
      "url": "https://developers.openai.com/mcp"
    }
  }
}
```

Обычно для этого проекта достаточно корневых `AGENTS.md` и `SKILLS.md`; plugin
создавай только если навыки нужно распространять между репозиториями.

## Быстрая проверка Flutter-проекта

```bash
flutter doctor -v
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Полезные официальные материалы:

- [Flutter Material 3 migration](https://docs.flutter.dev/release/breaking-changes/material-3-migration)
- [Material widgets](https://docs.flutter.dev/ui/widgets/material)
- [OpenAI Docs MCP](https://developers.openai.com/learn/docs-mcp)
