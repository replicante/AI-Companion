import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

// Importación correcta para Plasma 6
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root
    Plasmoid.icon: Qt.resolvedUrl("../images/robot.svg")
    Plasmoid.title: "AI Companion"

    compactRepresentation: Item {
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            source: Qt.resolvedUrl("../images/robot.svg")
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: Item {
        id: fullView
        Layout.minimumWidth: 360
        Layout.minimumHeight: 500
        Layout.preferredWidth: 460
        Layout.preferredHeight: 640

        property bool   chatMode:    false
        property bool   loading:     false
        property string errorMsg:    ""
        property var    history:     []
        property string lastResponse: ""

        // ── Historial persistente ────────────────────────────────────────
        // savedSessions: array de { id, title, provider, date, messages[] }
        property var    savedSessions:    []
        property bool   showHistory:      false
        property string currentSessionId: ""

        property var  ollamaProfiles: []
        property int  ollamaIndex:    plasmoid.configuration.activeOllamaIndex
        property var  quickPrompts:   []
        property bool searching:      false

        property string attachedFilePath:    ""
        property string attachedFileName:    ""
        property string attachedFileContent: ""
        property bool   attachedIsImage:     false

        property var    activeXhr: null   // referencia al XHR en curso para poder cancelarlo

        Component.onCompleted: {
            loadOllamaProfiles()
            loadQuickPrompts()
            loadSavedSessions()
        }

        Connections {
            target: plasmoid.configuration
            function onOllamaProfilesChanged() { fullView.loadOllamaProfiles() }
            function onQuickPromptsChanged()   { fullView.loadQuickPrompts() }
        }

        function loadOllamaProfiles() {
            try {
                ollamaProfiles = JSON.parse(plasmoid.configuration.ollamaProfiles || "[]")
            } catch(e) {
                ollamaProfiles = [{name:"llama3.2", model:"llama3.2"}]
            }
            if (ollamaIndex >= ollamaProfiles.length) ollamaIndex = 0
        }

        function loadQuickPrompts() {
            try {
                quickPrompts = JSON.parse(plasmoid.configuration.quickPrompts || "[]")
            } catch(e) {
                quickPrompts = []
            }
        }

        // ── Gestión de sesiones guardadas ──────────────────────────────
        function loadSavedSessions() {
            try {
                savedSessions = JSON.parse(plasmoid.configuration.chatHistory || "[]")
            } catch(e) {
                savedSessions = []
            }
        }

        function persistSessions() {
            plasmoid.configuration.chatHistory = JSON.stringify(savedSessions)
        }

        function generateId() {
            return Date.now().toString(36) + Math.random().toString(36).slice(2, 6)
        }

        function sessionTitle(messages) {
            for (var i = 0; i < messages.length; i++) {
                if (messages[i].role === "user") {
                    var t = messages[i].content
                    if (typeof t !== "string") t = "[adjunto]"
                    return t.length > 50 ? t.substring(0, 50) + "…" : t
                }
            }
            return "Conversación sin título"
        }

        // Guarda o actualiza la sesión actual. Se llama automáticamente
        // tras cada respuesta completa del asistente.
        function saveCurrentSession() {
            if (history.length === 0) return
            var now = new Date()
            var dateStr = now.toLocaleDateString("es-ES", {day:"2-digit", month:"2-digit", year:"2-digit"})
                        + " " + now.toLocaleTimeString("es-ES", {hour:"2-digit", minute:"2-digit"})

            var sessions = savedSessions.slice()

            if (currentSessionId) {
                for (var i = 0; i < sessions.length; i++) {
                    if (sessions[i].id === currentSessionId) {
                        sessions[i].messages = history.slice()
                        sessions[i].date     = dateStr
                        sessions[i].title    = sessionTitle(history)
                        break
                    }
                }
            } else {
                var id = generateId()
                currentSessionId = id
                sessions.unshift({
                    id:       id,
                    title:    sessionTitle(history),
                    provider: activeLabel(),
                    date:     dateStr,
                    messages: history.slice()
                })
                // Límite de 50 sesiones
                if (sessions.length > 50) sessions = sessions.slice(0, 50)
            }

            savedSessions = sessions
            persistSessions()
        }

        // Carga una sesión guardada y la reanuda en modo chat
        function loadSession(session) {
            history          = session.messages.slice()
            currentSessionId = session.id
            chatMode         = true
            showHistory      = false
            responseArea.text = renderHistory()
        }

        function deleteSession(id) {
            var sessions = savedSessions.filter(function(s) { return s.id !== id })
            savedSessions = sessions
            persistSessions()
        }

        // ──────────────────────────────────────────────────────────────
        readonly property var providerLabels: ({
            "claude":"Claude","gemini":"Gemini","openai":"ChatGPT",
            "grok":"Grok","qwen":"Qwen","ollama":"Ollama",
            "huggingface":"HuggingFace","nvidia":"NVIDIA",
            "openrouter":"OpenRouter","llamacpp":"llama.cpp"
        })

        function activeLabel() {
            var p = plasmoid.configuration.activeProvider
            if (p === "ollama" && ollamaProfiles.length > 0)
                return "Ollama · " + (ollamaProfiles[ollamaIndex].name || "?")
            return providerLabels[p] || p
        }

        function activeOllamaModel() {
            if (ollamaProfiles.length === 0) return "llama3.2"
            return ollamaProfiles[ollamaIndex].model || "llama3.2"
        }

        function renderHistory() {
            if (history.length === 0) return ""
            var lines = []
            for (var i = 0; i < history.length; i++) {
                var r = history[i]
                if (r.role === "user")           lines.push("▶ " + r.content)
                else if (r.role === "assistant") lines.push("◀ " + r.content)
            }
            return lines.join("\n\n")
        }

        function clearAttachment() {
            attachedFilePath    = ""
            attachedFileName    = ""
            attachedFileContent = ""
            attachedIsImage     = false
        }

        function getMimeType(name) {
            var ext = name.split(".").pop().toLowerCase()
            var map = {
                "png":"image/png","jpg":"image/jpeg","jpeg":"image/jpeg",
                "gif":"image/gif","webp":"image/webp","bmp":"image/bmp"
            }
            return map[ext] || "image/jpeg"
        }

        property string _pendingName:  ""
        property bool   _pendingIsImg: false

        function readFileAndAttach(fileUrl) {
            var path = decodeURIComponent(fileUrl.toString().replace(/^file:\/\//, ""))
            var name = path.replace(/.*\//, "")
            var ext  = name.split(".").pop().toLowerCase()
            var imageExts = ["png","jpg","jpeg","gif","webp","bmp"]
            var isImg = imageExts.indexOf(ext) !== -1

            _pendingName  = name
            _pendingIsImg = isImg
            attachedFilePath = path
            responseArea.text = "⏳ Leyendo " + name + "…"

            if (isImg) {
                fileReaderSource.connectSource(
                    "python3 -c \"import base64,sys;data=open(sys.argv[1],'rb').read();sys.stdout.write(base64.b64encode(data).decode())\" '" + path + "'",
                    0
                )
            } else if (ext === "pdf") {
                fileReaderSource.connectSource(
                    "pdftotext '" + path + "' - 2>/dev/null | head -c 15000",
                    0
                )
            } else if (ext === "docx" || ext === "odt" || ext === "doc") {
                fileReaderSource.connectSource(
                    "pandoc --to plain '" + path + "' 2>/dev/null | head -c 15000",
                    0
                )
            } else {
                fileReaderSource.connectSource(
                    "head -c 12000 '" + path + "'",
                    0
                )
            }
        }

        // ==================== SSE / STREAMING ====================

        function makeSseChunkParser(extractFn) {
            return function(raw, offset) {
                var delta = ""
                var chunk = raw.slice(offset)
                var newOffset = offset + chunk.length
                var lines = chunk.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (!line.startsWith("data:")) continue
                    var payload = line.slice(5).trim()
                    if (payload === "[DONE]") continue
                    try {
                        var obj = JSON.parse(payload)
                        var piece = extractFn(obj)
                        if (piece) delta += piece
                    } catch(e) {}
                }
                return { delta: delta, newOffset: newOffset }
            }
        }

        function oaiSseExtract(obj) {
            try { return obj.choices[0].delta.content || "" } catch(e) { return "" }
        }

        function makeOllamaChunkParser() {
            return function(raw, offset) {
                var delta = ""
                var chunk = raw.slice(offset)
                var newOffset = offset + chunk.length
                var lines = chunk.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (!line) continue
                    try {
                        var obj = JSON.parse(line)
                        if (obj.message && obj.message.content)
                            delta += obj.message.content
                    } catch(e) {}
                }
                return { delta: delta, newOffset: newOffset }
            }
        }

        function claudeSseExtract(obj) {
            try {
                if (obj.type === "content_block_delta" && obj.delta)
                    return obj.delta.text || ""
                return ""
            } catch(e) { return "" }
        }

        function openaiCompatReq(url, key, model, messages, max) {
            return {
                url: url,
                headers: {"Content-Type":"application/json","Authorization":"Bearer "+key},
                body: JSON.stringify({model:model, max_tokens:max, messages:messages, stream:true}),
                parseChunk: makeSseChunkParser(oaiSseExtract)
            }
        }

        function buildMessages(userPrompt) {
            var sys  = plasmoid.configuration.systemPrompt
            var base = [{role:"system", content:sys}]
            if (chatMode && history.length > 0) {
                for (var i = 0; i < history.length; i++) base.push(history[i])
            }
            if (attachedIsImage && attachedFileContent) {
                var p = plasmoid.configuration.activeProvider
                if (p === "claude" || p === "openai" || p === "gemini") {
                    base.push({
                        role: "user",
                        content: [
                            { type: "image",
                              source: { type:"base64",
                                        media_type: getMimeType(attachedFileName),
                                        data: attachedFileContent } },
                            { type: "text", text: userPrompt }
                        ]
                    })
                } else {
                    base.push({role:"user", content:"[Imagen adjunta no soportada]\n" + userPrompt})
                }
            } else if (!attachedIsImage && attachedFileContent) {
                var fileContext = "=== Archivo adjunto: " + attachedFileName + " ===\n"
                    + attachedFileContent.substring(0, 12000)
                    + "\n=== Fin del archivo ===\n\n"
                base.push({role:"user", content: fileContext + userPrompt})
            } else {
                base.push({role:"user", content: userPrompt})
            }
            return base
        }

        function buildRequest(userPrompt) {
            var cfg  = plasmoid.configuration
            var p    = cfg.activeProvider
            var max  = cfg.maxTokens
            var msgs = buildMessages(userPrompt)

            if (p === "claude") {
                var sysMsg   = msgs[0].content
                var userMsgs = msgs.slice(1)
                var claudeMsgs = userMsgs.map(function(m) {
                    if (m.role === "user" && Array.isArray(m.content)) {
                        var parts = m.content.map(function(c) {
                            if (c.type === "image") return { type:"image", source: c.source }
                            return { type:"text", text: c.text }
                        })
                        return { role:"user", content: parts }
                    }
                    return m
                })
                return {
                    url: "https://api.anthropic.com/v1/messages",
                    headers: {"Content-Type":"application/json",
                              "x-api-key":cfg.claudeApiKey,
                              "anthropic-version":"2023-06-01"},
                    body: JSON.stringify({model:cfg.claudeModel, max_tokens:max,
                        stream:true, system:sysMsg, messages:claudeMsgs}),
                    parseChunk: makeSseChunkParser(claudeSseExtract)
                }
            }
            if (p === "gemini") return {
                url: "https://generativelanguage.googleapis.com/v1beta/models/"
                    + cfg.geminiModel + ":streamGenerateContent?alt=sse&key=" + cfg.geminiApiKey,
                headers: {"Content-Type":"application/json"},
                body: JSON.stringify({
                    contents: msgs.filter(function(m){return m.role!=="system"})
                    .map(function(m){
                        if (Array.isArray(m.content)) {
                            var parts = m.content.map(function(c) {
                                if (c.type === "image")
                                    return { inline_data: { mime_type: c.source.media_type, data: c.source.data } }
                                return { text: c.text }
                            })
                            return { role: m.role==="assistant"?"model":"user", parts: parts }
                        }
                        return { role: m.role==="assistant"?"model":"user", parts:[{text:m.content}] }
                    }),
                    systemInstruction:{parts:[{text:msgs[0].content}]},
                    generationConfig:{maxOutputTokens:max}
                }),
                parseChunk: makeSseChunkParser(function(obj) {
                    try { return obj.candidates[0].content.parts[0].text || "" } catch(e) { return "" }
                })
            }
            if (p === "openai") {
                var oaiMsgs = msgs.map(function(m) {
                    if (m.role === "user" && Array.isArray(m.content)) {
                        var parts = m.content.map(function(c) {
                            if (c.type === "image")
                                return { type:"image_url", image_url:{ url:"data:"+c.source.media_type+";base64,"+c.source.data } }
                            return { type:"text", text:c.text }
                        })
                        return { role:"user", content:parts }
                    }
                    return m
                })
                return openaiCompatReq("https://api.openai.com/v1/chat/completions",
                                       cfg.openaiApiKey, cfg.openaiModel, oaiMsgs, max)
            }
            if (p === "grok")
                return openaiCompatReq("https://api.x.ai/v1/chat/completions",
                                       cfg.grokApiKey, cfg.grokModel, msgs, max)
            if (p === "qwen")
                return openaiCompatReq("https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
                                       cfg.qwenApiKey, cfg.qwenModel, msgs, max)
            if (p === "ollama") {
                var host = (cfg.ollamaHost || "http://localhost:11434").replace(/\/$/, "")
                return {
                    url: host + "/api/chat",
                    headers: {"Content-Type":"application/json"},
                    body: JSON.stringify({model:fullView.activeOllamaModel(), stream:true, messages:msgs}),
                    parseChunk: makeOllamaChunkParser()
                }
            }
            if (p === "huggingface") return {
                url: "https://api-inference.huggingface.co/models/" + cfg.hfModel + "/v1/chat/completions",
                headers: {"Content-Type":"application/json","Authorization":"Bearer "+cfg.hfApiKey},
                body: JSON.stringify({model:cfg.hfModel, max_tokens:max, messages:msgs, stream:true}),
                parseChunk: makeSseChunkParser(oaiSseExtract)
            }
            if (p === "nvidia") {
                var baseUrl = (cfg.nvidiaBaseUrl || "https://integrate.api.nvidia.com").replace(/\/$/, "")
                return openaiCompatReq(
                    baseUrl + "/v1/chat/completions",
                    cfg.nvidiaApiKey, cfg.nvidiaModel, msgs, max
                )
            }
            if (p === "openrouter") {
                // OpenRouter: OpenAI-compatible con headers adicionales opcionales
                var orReq = openaiCompatReq(
                    "https://openrouter.ai/api/v1/chat/completions",
                    cfg.openrouterApiKey, cfg.openrouterModel, msgs, max
                )
                orReq.headers["HTTP-Referer"] = "https://kde.org"
                orReq.headers["X-Title"] = "AI Companion KDE"
                return orReq
            }
            if (p === "llamacpp") {
                var lcHost = (cfg.llamacppHost || "http://localhost:8082").replace(/\/$/, "")
                return {
                    url: lcHost + "/v1/chat/completions",
                    headers: {"Content-Type":"application/json"},
                    body: JSON.stringify({model:"local-model", max_tokens:max, messages:msgs, stream:true}),
                    parseChunk: makeSseChunkParser(oaiSseExtract)
                }
            }
            return null
        }


        function cancelRequest() {
            if (activeXhr) {
                activeXhr.abort()
                activeXhr = null
            }
            if (chatMode && history.length > 0 && history[history.length - 1].role === "user") {
                history = history.slice(0, history.length - 1)
            }
            loading   = false
            searching = false
            responseArea.text = (chatMode && history.length > 0)
                ? renderHistory() + "\n\n⚠ Generación cancelada."
                : "⚠ Generación cancelada."
        }
        function sendPrompt(userPrompt) {
            if (!userPrompt.trim()) return
            var cfg = plasmoid.configuration
            var p   = cfg.activeProvider

            if (p !== "ollama" && p !== "llamacpp") {
                var key = p==="claude"?cfg.claudeApiKey:p==="gemini"?cfg.geminiApiKey
                :p==="openai"?cfg.openaiApiKey:p==="grok"?cfg.grokApiKey
                :p==="qwen"?cfg.qwenApiKey:p==="nvidia"?cfg.nvidiaApiKey
                :p==="openrouter"?cfg.openrouterApiKey:cfg.hfApiKey

                if (!key) {
                    errorMsg = "Sin API key para " + activeLabel() + ". Clic derecho → Configurar."
                    loading = false; return
                }
            }

            if (cfg.enableSearch) {
                fetchSearchAndSend(userPrompt)
            } else {
                dispatchPrompt(userPrompt, "")
            }
        }

        function fetchSearchAndSend(userPrompt) {
            var cfg   = plasmoid.configuration
            var host  = (cfg.searxngHost || "http://127.0.0.1:8888").replace(/\/$/, "")
            var limit = cfg.searchLimit || 3
            var query = encodeURIComponent(userPrompt.substring(0, 200))
            var url   = host + "/search?q=" + query + "&format=json&language=es&categories=general"

            searching = true
            loading   = true
            errorMsg  = ""
            responseArea.text = "🔍 Buscando en la web…"

            var xhr = new XMLHttpRequest()
            fullView.activeXhr = xhr
            xhr.open("GET", url)
            xhr.setRequestHeader("Accept", "application/json")
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                searching = false
                var context = ""
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText)
                        var results = data.results || []
                        var snippets = []
                        for (var i = 0; i < Math.min(results.length, limit); i++) {
                            var r = results[i]
                            var title   = r.title   || ""
                            var snippet = r.content || r.snippet || ""
                            var url2    = r.url     || ""
                            if (snippet)
                                snippets.push("[" + (i+1) + "] " + title + "\n" + snippet + "\nFuente: " + url2)
                        }
                        if (snippets.length > 0)
                            context = "=== Resultados de búsqueda web ===\n" + snippets.join("\n\n") + "\n=== Fin resultados ===\n\n"
                    } catch(e) {}
                }
                dispatchPrompt(userPrompt, context)
            }
            xhr.send()
        }

        // ==================== DISPATCH CON STREAMING ====================
        function dispatchPrompt(userPrompt, searchContext) {
            loading  = true
            errorMsg = ""

            var enrichedPrompt = searchContext
                ? searchContext + "Teniendo en cuenta la información anterior, responde a: " + userPrompt
                : userPrompt

            var attachLabel = attachedFileName ? " 📎" + attachedFileName : ""

            if (chatMode) {
                var newHistory = history.slice()
                newHistory.push({role:"user", content:userPrompt})
                history = newHistory
                responseArea.text = renderHistory() + "\n\n⏳ Pensando…"
            } else {
                responseArea.text = searchContext
                    ? "🌐 Contexto web obtenido." + (attachLabel ? " " + attachLabel : "") + " ⏳ Pensando…"
                    : (attachLabel ? attachLabel + " ⏳ Pensando…" : "⏳ Pensando…")
            }

            var req = buildRequest(enrichedPrompt)
            if (!req) {
                errorMsg = "Proveedor no reconocido."
                loading = false
                return
            }

            var parseChunkFn = req.parseChunk
            var streamOffset  = 0
            var accumulated   = ""

            var xhr = new XMLHttpRequest()
            fullView.activeXhr = xhr
            xhr.open("POST", req.url)
            for (var h in req.headers) xhr.setRequestHeader(h, req.headers[h])

            xhr.onreadystatechange = function() {

                if (xhr.readyState === XMLHttpRequest.LOADING && xhr.status === 200) {
                    var result = parseChunkFn(xhr.responseText, streamOffset)
                    streamOffset = result.newOffset
                    if (result.delta) {
                        accumulated += result.delta
                        if (chatMode) {
                            responseArea.text = renderHistory() + "\n\n◀ " + accumulated
                        } else {
                            responseArea.text = accumulated
                        }
                    }
                    return
                }

                if (xhr.readyState !== XMLHttpRequest.DONE) return
                loading = false
                fullView.activeXhr = null

                if (xhr.status === 200) {
                    var last = parseChunkFn(xhr.responseText, streamOffset)
                    if (last.delta) accumulated += last.delta

                    if (!accumulated) {
                        try {
                            var d = JSON.parse(xhr.responseText)
                            accumulated = (d.content && d.content[0] && d.content[0].text)
                                || (d.choices && d.choices[0] && d.choices[0].message && d.choices[0].message.content)
                                || (d.message && d.message.content)
                                || ""
                        } catch(e) {}
                    }

                    lastResponse = accumulated

                    if (chatMode) {
                        var nh = history.slice()
                        nh.push({role:"assistant", content:accumulated})
                        history = nh
                        responseArea.text = renderHistory()
                        // Auto-guardar sesión tras cada respuesta completa
                        saveCurrentSession()
                    } else {
                        responseArea.text = accumulated || "⚠ Respuesta vacía."
                    }
                    clearAttachment()
                } else {
                    try {
                        var err = JSON.parse(xhr.responseText)
                        errorMsg = "Error " + xhr.status + ": "
                            + (err.error ? (err.error.message || JSON.stringify(err.error)) : xhr.responseText.substring(0,200))
                    } catch(_) {
                        errorMsg = "HTTP " + xhr.status
                    }
                    responseArea.text = "⚠ " + errorMsg
                }
            }
            xhr.send(req.body)
        }

        // ==================== PORTAPAPELES ====================

        function getClipboard() {
            clipboardBridge.text = ""
            clipboardBridge.forceActiveFocus()
            clipboardBridge.selectAll()
            clipboardBridge.paste()
            var clip = clipboardBridge.text
            clipboardBridge.text = ""
            return clip
        }

        function summarizeClipboard() {
            var clip = getClipboard()
            if (!clip || !clip.trim()) {
                errorMsg = "Portapapeles vacío."
                responseArea.text = "⚠ " + errorMsg
                return
            }
            sendPrompt("Resume el siguiente texto en 3-5 puntos clave (texto plano, sin markdown):\n\n" + clip)
        }

        function improveClipboard() {
            var clip = getClipboard()
            if (!clip || !clip.trim()) {
                errorMsg = "Portapapeles vacío."
                responseArea.text = "⚠ " + errorMsg
                return
            }
            sendPrompt("Mejora la redacción de este texto manteniendo el significado original (texto plano, sin markdown):\n\n" + clip)
        }

        function exportConversation() {
            var content = ""
            if (chatMode && history.length > 0) {
                content = "=== AI Companion — Conversación ===\n"
                content += "Proveedor: " + activeLabel() + "\n"
                content += "Fecha: " + new Date().toLocaleString() + "\n"
                content += "=".repeat(36) + "\n\n"
                for (var i = 0; i < history.length; i++) {
                    var r = history[i]
                    if (r.role === "user")
                        content += "[Tú]\n" + r.content + "\n\n"
                    else if (r.role === "assistant")
                        content += "[" + activeLabel() + "]\n" + r.content + "\n\n"
                }
            } else if (responseArea.text && responseArea.text.length > 0) {
                content = "=== AI Companion — Respuesta ===\n"
                content += "Proveedor: " + activeLabel() + "\n"
                content += "Fecha: " + new Date().toLocaleString() + "\n"
                content += "=".repeat(36) + "\n\n"
                content += responseArea.text
            } else {
                errorMsg = "No hay conversación que exportar."
                responseArea.text = "⚠ " + errorMsg
                return
            }
            exportBridge.text = content
            exportBridge.selectAll()
            exportBridge.copy()
            exportBridge.text = ""
            responseArea.text = "📋 Conversación copiada al portapapeles.\n\nPuedes pegar en un editor y guardar."
        }

        // ==================== LECTOR DE ARCHIVOS ====================
        Plasma5Support.DataSource {
            id: fileReaderSource
            engine: "executable"
            connectedSources: []

            onNewData: function(source, data) {
                var output = data["stdout"] || ""
                var err    = data["stderr"] || ""
                disconnectSource(source)

                if (err && !output) {
                    fullView.errorMsg = "Error leyendo archivo: " + err.substring(0, 120)
                    responseArea.text = "⚠ " + fullView.errorMsg
                    fullView._pendingName  = ""
                    fullView._pendingIsImg = false
                    return
                }

                var name  = fullView._pendingName
                var isImg = fullView._pendingIsImg

                if (isImg) {
                    fullView.attachedFileName    = name
                    fullView.attachedFileContent = output.trim()
                    fullView.attachedIsImage     = true
                    responseArea.text = "🖼 Imagen adjunta: " + name
                        + "\n\nEscribe tu instrucción y pulsa Enviar."
                } else {
                    var ext2 = name.split(".").pop().toLowerCase()
                    if ((ext2 === "pdf" || ext2 === "docx" || ext2 === "odt" || ext2 === "doc")
                            && output.trim().length === 0) {
                        fullView.errorMsg = "No se pudo extraer texto de «" + name + "»."
                        responseArea.text = "⚠ " + fullView.errorMsg
                        fullView._pendingName  = ""
                        fullView._pendingIsImg = false
                        return
                    }
                    var emoji = (ext2 === "pdf") ? "📑"
                              : (ext2 === "docx" || ext2 === "doc" || ext2 === "odt") ? "📝"
                              : "📄"
                    fullView.attachedFileName    = name
                    fullView.attachedFileContent = output
                    fullView.attachedIsImage     = false
                    responseArea.text = emoji + " Archivo adjunto: " + name
                        + " (" + output.length + " caracteres)"
                        + "\n\nEscribe tu instrucción y pulsa Enviar."
                }
                fullView._pendingName  = ""
                fullView._pendingIsImg = false
            }
        }

        TextEdit { id: clipboardBridge; visible:false; width:0; height:0 }
        TextEdit { id: exportBridge;    visible:false; width:0; height:0 }

        FileDialog {
            id: fileDialog
            title: "Adjuntar archivo"
            fileMode: FileDialog.OpenFile
            nameFilters: [
                "Todos los soportados (*.txt *.md *.csv *.json *.xml *.html *.py *.js *.qml *.sh *.log *.pdf *.docx *.odt *.doc *.png *.jpg *.jpeg *.gif *.webp *.bmp)",
                "Documentos (*.pdf *.docx *.odt *.doc)",
                "Texto plano (*.txt *.md *.csv *.json *.xml *.html *.py *.js *.qml *.sh *.log)",
                "Imágenes (*.png *.jpg *.jpeg *.gif *.webp *.bmp)",
                "Todos los archivos (*)"
            ]
            onAccepted: { fullView.readFileAndAttach(selectedFile) }
        }

        // ==================== UI PRINCIPAL ====================
        ColumnLayout {
            anchors { fill: parent; margins: 12 }
            spacing: 6

            // ── Barra superior ─────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Kirigami.Icon {
                    source: Qt.resolvedUrl("../images/robot.svg")
                    width:20; height:20
                }
                PlasmaExtras.Heading {
                    level:4; text:"AI Companion"; Layout.fillWidth:true
                }

                Loader {
                    active: plasmoid.configuration.activeProvider === "ollama" && fullView.ollamaProfiles.length > 1
                    sourceComponent: QQC2.ComboBox {
                        implicitWidth: 140
                        model: fullView.ollamaProfiles
                        textRole: "name"
                        currentIndex: fullView.ollamaIndex
                        onActivated: {
                            fullView.ollamaIndex = currentIndex
                            plasmoid.configuration.activeOllamaIndex = currentIndex
                        }
                    }
                }
                Loader {
                    active: !(plasmoid.configuration.activeProvider === "ollama" && fullView.ollamaProfiles.length > 1)
                    sourceComponent: Rectangle {
                        height:20; width: badgeLbl.implicitWidth + 12
                        radius:10; color: Kirigami.Theme.highlightColor; opacity:0.85
                        QQC2.Label {
                            id: badgeLbl
                            anchors.centerIn: parent
                            text: fullView.activeLabel()
                            font.pixelSize:11
                            color: Kirigami.Theme.highlightedTextColor
                        }
                    }
                }

                Rectangle {
                    visible: plasmoid.configuration.enableSearch
                    height: 20; width: searchLbl.implicitWidth + 12
                    radius: 10
                    color: fullView.searching ? Kirigami.Theme.neutralTextColor : "#1a7340"
                    opacity: 0.85
                    QQC2.Label {
                        id: searchLbl
                        anchors.centerIn: parent
                        text: fullView.searching ? "🔍…" : "🌐 Web"
                        font.pixelSize: 11; color: "white"
                    }
                }

                // Botón historial ← NUEVO
                PlasmaComponents3.ToolButton {
                    icon.name: "view-history"
                    checkable: true
                    checked: fullView.showHistory
                    onClicked: fullView.showHistory = !fullView.showHistory
                    QQC2.ToolTip.text: fullView.showHistory
                        ? "Cerrar historial"
                        : "Historial (" + fullView.savedSessions.length + " conversaciones)"
                    QQC2.ToolTip.visible: hovered
                }

                PlasmaComponents3.ToolButton {
                    icon.name: fullView.chatMode ? "dialog-messages" : "question"
                    checkable: true
                    checked: fullView.chatMode
                    onClicked: {
                        fullView.chatMode = !fullView.chatMode
                        if (!fullView.chatMode) {
                            fullView.history = []
                            fullView.currentSessionId = ""
                            responseArea.text = ""
                        }
                    }
                    QQC2.ToolTip.text: fullView.chatMode
                        ? "Modo chat activo (clic para desactivar)"
                        : "Activar modo chat"
                    QQC2.ToolTip.visible: hovered
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "configure"
                    onClicked: plasmoid.internalAction("configure").trigger()
                }
            }

            // ── Badge modo chat ────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: chatModeLabel.implicitHeight + 6
                visible: fullView.chatMode && !fullView.showHistory
                color: Kirigami.Theme.highlightColor; opacity: 0.15; radius: 4
                QQC2.Label {
                    id: chatModeLabel
                    anchors.centerIn: parent
                    text: "Modo conversación activo  ·  " + Math.floor(fullView.history.length / 2) + " intercambios"
                    font.pixelSize: 11; color: Kirigami.Theme.textColor
                }
            }

            // ── Banner adjunto ─────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: attachBannerRow.implicitHeight + 8
                visible: fullView.attachedFileName !== "" && !fullView.showHistory
                color: fullView.attachedIsImage ? "#1a3d6b" : "#1e3d12"; radius: 4
                RowLayout {
                    id: attachBannerRow
                    anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
                    spacing: 4
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: (fullView.attachedIsImage ? "🖼 " : "📄 ") + fullView.attachedFileName
                        font.pixelSize: 11; color: "#ddeeff"; elide: Text.ElideMiddle
                    }
                    PlasmaComponents3.ToolButton {
                        icon.name: "edit-delete"; flat: true
                        onClicked: fullView.clearAttachment()
                        implicitWidth: 22; implicitHeight: 22
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            // ═══════════════════════════════════════════════════════════
            // PANEL HISTORIAL
            // ═══════════════════════════════════════════════════════════
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: fullView.showHistory
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaExtras.Heading {
                        level: 5
                        text: "Historial de conversaciones"
                        Layout.fillWidth: true
                    }
                    PlasmaComponents3.Button {
                        text: "Nueva conversación"
                        icon.name: "document-new"
                        flat: true
                        onClicked: {
                            fullView.history = []
                            fullView.currentSessionId = ""
                            fullView.chatMode = true
                            fullView.showHistory = false
                            responseArea.text = ""
                        }
                    }
                }

                // Estado vacío
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: fullView.savedSessions.length === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Kirigami.Icon {
                            source: "view-history"
                            width: 48; height: 48
                            anchors.horizontalCenter: parent.horizontalCenter
                            opacity: 0.3
                        }
                        QQC2.Label {
                            text: "Aún no hay conversaciones guardadas."
                            horizontalAlignment: Text.AlignHCenter
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: 12
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        QQC2.Label {
                            text: "Activa el modo chat 💬 y empieza a hablar.\nLas sesiones se guardan automáticamente."
                            horizontalAlignment: Text.AlignHCenter
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: 11
                            anchors.horizontalCenter: parent.horizontalCenter
                            wrapMode: Text.Wrap
                            width: 280
                        }
                    }
                }

                // Lista de sesiones
                QQC2.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    visible: fullView.savedSessions.length > 0

                    ListView {
                        id: sessionsList
                        model: fullView.savedSessions
                        spacing: 4
                        clip: true

                        delegate: Rectangle {
                            width: sessionsList.width
                            height: sessionItemCol.implicitHeight + 14
                            radius: 6

                            // Destacar la sesión actualmente cargada
                            color: modelData.id === fullView.currentSessionId
                                ? Kirigami.Theme.highlightColor
                                : Kirigami.Theme.alternateBackgroundColor
                            opacity: 1.0

                            MouseArea {
                                anchors { fill: parent; rightMargin: 32 }
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: fullView.loadSession(modelData)

                                // Efecto hover sutil
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: Kirigami.Theme.highlightColor
                                    opacity: parent.containsMouse && modelData.id !== fullView.currentSessionId ? 0.08 : 0
                                }
                            }

                            ColumnLayout {
                                id: sessionItemCol
                                anchors {
                                    left:   parent.left
                                    right:  deleteSessionBtn.left
                                    top:    parent.top
                                    margins: 8
                                    rightMargin: 4
                                }
                                spacing: 3

                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    font.pixelSize: 12
                                    font.bold: modelData.id === fullView.currentSessionId
                                    color: modelData.id === fullView.currentSessionId
                                        ? Kirigami.Theme.highlightedTextColor
                                        : Kirigami.Theme.textColor
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    spacing: 4
                                    Repeater {
                                        model: [
                                            modelData.provider,
                                            "·",
                                            Math.floor((modelData.messages || []).length / 2) + " intercambios",
                                            "·",
                                            modelData.date
                                        ]
                                        QQC2.Label {
                                            text: modelData
                                            font.pixelSize: 10
                                            color: fullView.currentSessionId === (sessionsList.model[index] || {}).id
                                                ? Kirigami.Theme.highlightedTextColor
                                                : Kirigami.Theme.disabledTextColor
                                            opacity: 0.85
                                        }
                                    }
                                }
                            }

                            PlasmaComponents3.ToolButton {
                                id: deleteSessionBtn
                                anchors {
                                    right:         parent.right
                                    verticalCenter: parent.verticalCenter
                                    rightMargin:   4
                                }
                                icon.name: "edit-delete"
                                flat: true
                                implicitWidth: 26; implicitHeight: 26
                                opacity: 0.55
                                onClicked: {
                                    if (modelData.id === fullView.currentSessionId)
                                        fullView.currentSessionId = ""
                                    fullView.deleteSession(modelData.id)
                                }
                                QQC2.ToolTip.text: "Eliminar conversación"
                                QQC2.ToolTip.visible: hovered
                            }
                        }
                    }
                }

                // Botón borrar todo
                PlasmaComponents3.Button {
                    Layout.alignment: Qt.AlignRight
                    text: "Borrar todo el historial"
                    icon.name: "edit-clear-all"
                    flat: true
                    visible: fullView.savedSessions.length > 0
                    onClicked: {
                        fullView.savedSessions = []
                        fullView.persistSessions()
                        fullView.currentSessionId = ""
                    }
                }
            }

            // ═══════════════════════════════════════════════════════════
            // ÁREA DE CHAT
            // ═══════════════════════════════════════════════════════════
            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                visible: !fullView.showHistory

                QQC2.TextArea {
                    id: responseArea
                    width: parent.width
                    readOnly: true
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    font.pixelSize: 13
                    padding: 8
                    background: Rectangle {
                        color: Kirigami.Theme.alternateBackgroundColor
                        radius: 6
                        border.color: Kirigami.Theme.disabledTextColor
                        border.width: 0.5
                    }
                    text: "Pregunta algo a " + fullView.activeLabel() + "."
                    color: Kirigami.Theme.textColor
                    opacity: (fullView.loading || text === "Pregunta algo a " + fullView.activeLabel() + ".") ? 0.5 : 1.0
                }
            }

            // ── Botones de acción ──────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: !fullView.showHistory
                    && responseArea.text.length > 0
                    && !responseArea.text.startsWith("Pregunta algo")

                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    text:"Copiar"; icon.name:"edit-copy"; flat:true
                    onClicked: {
                        responseArea.selectAll()
                        responseArea.copy()
                        responseArea.deselect()
                    }
                }
                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    text:"Exportar .txt"; icon.name:"document-save"; flat:true
                    onClicked: fullView.exportConversation()
                }
                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    text:"Limpiar"; icon.name:"edit-clear"; flat:true
                    onClicked: {
                        fullView.history = []
                        fullView.currentSessionId = ""
                        fullView.lastResponse = ""
                        fullView.clearAttachment()
                        responseArea.text = "Pregunta algo a " + fullView.activeLabel() + "."
                        fullView.errorMsg = ""
                        promptInput.forceActiveFocus()
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true; visible: !fullView.showHistory }

            // ── Campo de input ─────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: !fullView.showHistory

                QQC2.TextField {
                    id: promptInput
                    Layout.fillWidth: true
                    placeholderText: fullView.chatMode
                        ? "Continúa la conversación… (Enter)"
                        : (fullView.attachedFileName
                            ? "Instrucción para el archivo adjunto… (Enter)"
                            : "Pregunta algo… (Enter para enviar)")
                    font.pixelSize: 13
                    enabled: !fullView.loading && !fullView.searching
                    Keys.onReturnPressed: (event) => {
                        if (!(event.modifiers & Qt.ShiftModifier) && text.trim().length > 0) {
                            fullView.sendPrompt(text.trim())
                            text = ""
                            event.accepted = true
                        }
                    }
                }
                PlasmaComponents3.Button {
                    icon.name: "go-next"
                    enabled: !fullView.loading && !fullView.searching && promptInput.text.trim().length > 0
                    onClicked: {
                        fullView.sendPrompt(promptInput.text.trim())
                        promptInput.text = ""
                    }
                }

                // Botón cancelar: visible solo mientras se genera la respuesta
                PlasmaComponents3.Button {
                    icon.name: "process-stop"
                    visible: fullView.loading || fullView.searching
                    onClicked: fullView.cancelRequest()
                    QQC2.ToolTip.text: "Cancelar generación"
                    QQC2.ToolTip.visible: hovered
                }
            }

            // ── Botones de herramientas ────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: !fullView.showHistory

                PlasmaComponents3.Button {
                    text: "Resumir"; icon.name: "edit-paste"
                    enabled: !fullView.loading && !fullView.searching
                    onClicked: fullView.summarizeClipboard()
                }
                PlasmaComponents3.Button {
                    text: "Mejorar"; icon.name: "document-edit"
                    enabled: !fullView.loading && !fullView.searching
                    onClicked: fullView.improveClipboard()
                }
                PlasmaComponents3.Button {
                    text: fullView.attachedFileName ? "📎 …" : "Adjuntar"
                    icon.name: "document-open"
                    enabled: !fullView.loading && !fullView.searching
                    flat: true
                    onClicked: fileDialog.open()
                    QQC2.ToolTip.text: fullView.attachedFileName
                        ? "Adjunto: " + fullView.attachedFileName + "\n(clic para cambiar)"
                        : "Adjuntar archivo (texto, PDF, DOCX, imagen…)"
                    QQC2.ToolTip.visible: hovered
                }
                PlasmaComponents3.Button {
                    text: "Prompts ▾"; icon.name: "format-list-unordered"
                    enabled: !fullView.loading && !fullView.searching && fullView.quickPrompts.length > 0
                    onClicked: quickMenu.open()

                    QQC2.Menu {
                        id: quickMenu
                        Repeater {
                            model: fullView.quickPrompts
                            QQC2.MenuItem {
                                text: modelData.label
                                onTriggered: {
                                    var clip = fullView.getClipboard()
                                    var prompt = modelData.prompt
                                    if (clip && clip.trim()) {
                                        fullView.sendPrompt(prompt + clip)
                                    } else {
                                        promptInput.text = prompt
                                        promptInput.forceActiveFocus()
                                        promptInput.cursorPosition = promptInput.text.length
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
