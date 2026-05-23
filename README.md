# AI Companion — KDE Plasma 6 Plasmoid

> **⚠ Early development — expect bugs**
> This project is in an early stage of development. The code may contain multiple errors, incomplete features, and rough edges. Use at your own risk and feel free to open issues or PRs.

A minimalist AI assistant plasmoid for **KDE Plasma 6** that lives in your panel or desktop. Supports streaming responses from a wide range of AI providers — both cloud APIs and local inference servers.

[Vista principal](https://github.com/user-attachments/assets/9197800a-6adc-4410-99b4-40b481b277b2)

![Plasma 6](https://img.shields.io/badge/Plasma-6.x-blue?logo=kde)
![QML](https://img.shields.io/badge/QML-Qt6-green)
![License](https://img.shields.io/badge/license-GPL--2.0%2B-orange)
![Status](https://img.shields.io/badge/status-early%20development-red)

---

## Supported providers
[Vista preferencias](https://github.com/user-attachments/assets/1135cf85-c540-47fc-af1f-220e369cfd18)
| Provider | Type | Notes |
|---|---|---|
| **Claude** | Cloud API | Anthropic — requires API key |
| **Gemini** | Cloud API | Google — requires API key |
| **ChatGPT** | Cloud API | OpenAI — requires API key |
| **Grok** | Cloud API | xAI — requires API key |
| **Qwen** | Cloud API | Alibaba DashScope — requires API key |
| **HuggingFace** | Cloud API | Inference API — requires API key |
| **NVIDIA** | Cloud API | build.nvidia.com — requires API key |
| **OpenRouter** | Cloud API | Multi-model gateway — requires API key |
| **Ollama** | Local | Multiple named profiles supported |
| **llama.cpp** | Local | OpenAI-compatible server (`llama-server`) |

---

## Features

- **Streaming responses** (SSE) for all providers
- **Chat mode** — multi-turn conversation with persistent history (up to 50 sessions)
- **File attachments** — plain text, Markdown, CSV, JSON, Python/JS/QML scripts, PDF (`pdftotext`), DOCX/ODT (`pandoc`), and images (PNG, JPG, WebP, GIF…)
- **Vision support** — inline image input for Claude, OpenAI, and Gemini
- **Web search integration** — optional SearXNG backend injects search results as context before the prompt
- **Clipboard tools** — one-click summarise or improve text from clipboard
- **Quick prompts** — configurable menu of reusable prompt templates
- **Cancel button** — abort generation mid-stream
- **Export** — copy full conversation to clipboard as plain text
- **Ollama profiles** — multiple named model profiles switchable from the toolbar
- **Session history panel** — browse, resume, and delete past conversations
- **Configurable system prompt** and max token limit

---

## Requirements

- KDE Plasma **6.x** (tested on 6.6+)
- Qt **6.x** / KDE Frameworks **6.x**
- `plasma5support` (provides the `executable` DataSource used for file reading)
- Optional: `pdftotext` (poppler-utils) — for PDF attachment support
- Optional: `pandoc` — for DOCX/ODT attachment support
- For Ollama: a running `ollama serve` instance
- For llama.cpp: a running `llama-server` with OpenAI-compatible API (default: `http://localhost:8082`)
- For web search: a running [SearXNG](https://github.com/searxng/searxng) instance (default: `http://127.0.0.1:8888`)

---

## Installation

```bash
git clone https://github.com/replicante/aicompanion.git
cd aicompanion
bash install.sh
```

The script copies the plasmoid to `~/.local/share/plasma/plasmoids/com.local.aicompanion/` and restarts `plasmashell`.

After installation: **right-click the panel → Add Widgets → AI Companion**.

---

## Configuration

Right-click the widget → **Configure**:

- Select your active provider
- Enter the API key for the chosen provider
- Set the model name (editable — you can type any valid model string)
- Adjust max tokens and system prompt
- For Ollama: add named profiles (display name + model identifier)
- For llama.cpp: set the server host URL
- For web search: enable the toggle and set the SearXNG host
- Define custom quick prompts (label + prompt template)

---

## Known limitations and caveats

- **Early development**: the codebase is a single large QML file and has not been refactored for maintainability. There are likely bugs in edge cases.
- API keys are stored in KConfig (the standard Plasma configuration backend). They are **not encrypted**.
- The file reader uses `Plasma5Support.DataSource` with the `executable` engine to shell out to `python3`, `pdftotext`, and `pandoc`. This is a known Plasma 5 compatibility shim — it may break in future Plasma 6 releases.
- The clipboard read/write mechanism (`TextEdit` paste/copy bridge) is a workaround for the lack of a `Clipboard` API in QML plasmoids, and may behave unexpectedly on some setups.
- Image support is only available with Claude, OpenAI, and Gemini. Other providers receive a fallback text message.
- Chat history is persisted in KConfig as a JSON string. Very long sessions may hit storage limits.
- The Gemini provider does not pass the `system` message as a chat turn (uses `systemInstruction`), which may cause inconsistent behaviour depending on the model.
- No support for function calling / tool use.
- No markdown rendering in the response area (plain text only by design).

---

## Project structure

```
aicompanion/
├── metadata.json                   # Plasmoid metadata (Plasma 6 format)
├── install.sh                      # Install script
└── contents/
    ├── config/
    │   ├── main.xml                # KConfig schema (all settings)
    │   └── config.qml              # Config UI entry point
    ├── ui/
    │   ├── main.qml                # Main plasmoid UI + all logic
    │   └── configGeneral.qml       # Settings panel UI
    └── images/
        └── robot.svg               # Panel icon
```

---

## Contributing

Issues, bug reports, and pull requests are welcome. Given the early state of the project, please don't expect a stable API or consistent code style.

---

## License

GPL-2.0-or-later — see [COPYING](COPYING) or https://www.gnu.org/licenses/gpl-2.0.html

