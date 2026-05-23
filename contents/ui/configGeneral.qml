import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: configRoot
    implicitHeight: Math.min(mainColumn.implicitHeight + 32, 600)

    // --- ALIAS DE CONFIGURACIÓN ---
    property alias cfg_activeProvider:  providerCombo.currentValue
    property alias cfg_maxTokens:       maxTokensSpinBox.value
    property alias cfg_systemPrompt:    systemPromptArea.text
    property alias cfg_claudeApiKey:    claudeKeyField.text
    property alias cfg_claudeModel:     claudeModelField.text
    property alias cfg_geminiApiKey:    geminiKeyField.text
    property alias cfg_geminiModel:     geminiModelField.text
    property alias cfg_openaiApiKey:    openaiKeyField.text
    property alias cfg_openaiModel:     openaiModelField.text
    property alias cfg_grokApiKey:      grokKeyField.text
    property alias cfg_grokModel:       grokModelField.text
    property alias cfg_qwenApiKey:      qwenKeyField.text
    property alias cfg_qwenModel:       qwenModelField.text
    property alias cfg_ollamaHost:      ollamaHostField.text
    property alias cfg_hfApiKey:        hfKeyField.text
    property alias cfg_hfModel:         hfModelField.text
    // NVIDIA
    property alias cfg_nvidiaApiKey:    nvidiaKeyField.text
    property alias cfg_nvidiaModel:     nvidiaModelField.text
    property alias cfg_nvidiaBaseUrl:   nvidiaBaseUrlField.text
    // OpenRouter
    property alias cfg_openrouterApiKey:   openrouterKeyField.text
    property alias cfg_openrouterModel:    openrouterModelField.text
    // llama.cpp
    property alias cfg_llamacppHost:       llamacppHostField.text

    property string cfg_ollamaProfiles: "[]"
    property string cfg_quickPrompts:   "[]"

    // Alias para la búsqueda web
    property alias cfg_enableSearch:    searchToggle.checked
    property alias cfg_searxngHost:     searxngField.text
    property alias cfg_searchLimit:     searchLimitSpin.value

    property var providers: [
        {value:"claude",      label:"Claude"},
        {value:"gemini",      label:"Gemini"},
        {value:"openai",      label:"ChatGPT"},
        {value:"grok",        label:"Grok"},
        {value:"qwen",        label:"Qwen"},
        {value:"ollama",      label:"Ollama"},
        {value:"huggingface", label:"HuggingFace"},
        {value:"nvidia",      label:"NVIDIA"},
        {value:"openrouter",  label:"OpenRouter"},
        {value:"llamacpp",    label:"llama.cpp"}
    ]

    function providerIndex(val) {
        for (var i = 0; i < providers.length; i++)
            if (providers[i].value === val) return i
                return 0
    }

    ListModel { id: ollamaModel }
    ListModel { id: quickModel  }

    function loadOllamaProfiles() {
        ollamaModel.clear()
        try {
            var arr = JSON.parse(plasmoid.configuration.ollamaProfiles || "[]")
            for (var i = 0; i < arr.length; i++)
                ollamaModel.append({pname: arr[i].name, pmodel: arr[i].model})
        } catch(e) {
            ollamaModel.append({pname:"llama3.2", pmodel:"llama3.2"})
        }
    }

    function saveOllamaProfiles() {
        var arr = []
        for (var i = 0; i < ollamaModel.count; i++)
            arr.push({name:ollamaModel.get(i).pname, model:ollamaModel.get(i).pmodel})
            cfg_ollamaProfiles = JSON.stringify(arr)
    }

    function loadQuickPrompts() {
        quickModel.clear()
        try {
            var arr = JSON.parse(plasmoid.configuration.quickPrompts || "[]")
            for (var i = 0; i < arr.length; i++)
                quickModel.append({plabel:arr[i].label, pprompt:arr[i].prompt})
        } catch(e) {}
    }

    function saveQuickPrompts() {
        var arr = []
        for (var i = 0; i < quickModel.count; i++)
            arr.push({label:quickModel.get(i).plabel, prompt:quickModel.get(i).pprompt})
            cfg_quickPrompts = JSON.stringify(arr)
    }

    Component.onCompleted: {
        loadOllamaProfiles()
        loadQuickPrompts()
        providerCombo.currentIndex = providerIndex(plasmoid.configuration.activeProvider)
    }

    QQC2.ScrollView {
        id: scrollView
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
        QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AsNeeded

        ColumnLayout {
            id: mainColumn
            width: scrollView.availableWidth
            x: 16
            y: 16
            // Restamos los márgenes del width
            implicitWidth: scrollView.availableWidth - 32
            spacing: 16

        // --- SECCIÓN 1: GENERAL ---
        Kirigami.FormLayout {
            Layout.fillWidth: true
            QQC2.ComboBox {
                id: providerCombo
                Kirigami.FormData.label: "Proveedor activo:"
                textRole:"label"; valueRole:"value"
                model: configRoot.providers
            }
            QQC2.SpinBox {
                id: maxTokensSpinBox
                Kirigami.FormData.label: "Max tokens:"
                from:256; to:8192; stepSize:256
            }
            QQC2.TextArea {
                id: systemPromptArea
                Kirigami.FormData.label: "System prompt:"
                Layout.preferredWidth:300; Layout.minimumHeight:64
                wrapMode: TextEdit.Wrap
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // --- SECCIÓN 2: TABS PROVEEDORES ---
        QQC2.TabBar {
            id: tabBar
            Layout.fillWidth: true
            Repeater {
                model: configRoot.providers
                QQC2.TabButton { text: modelData.label }
            }
        }

        StackLayout {
            id: providersStack
            Layout.fillWidth: true
            currentIndex: tabBar.currentIndex

            // Claude
            Kirigami.FormLayout {
                Kirigami.InlineMessage { Layout.fillWidth:true;visible:true;type:Kirigami.MessageType.Information;text:"console.anthropic.com → API Keys" }
                ProviderKeyRow { id:claudeKeyField; Kirigami.FormData.label:"API Key:" }
                QQC2.TextField { id:claudeModelField; Kirigami.FormData.label:"Modelo:"; Layout.preferredWidth:280 }
            }
            // Gemini
            Kirigami.FormLayout {
                Kirigami.InlineMessage { Layout.fillWidth:true;visible:true;type:Kirigami.MessageType.Information;text:"aistudio.google.com → Get API key" }
                ProviderKeyRow { id:geminiKeyField; Kirigami.FormData.label:"API Key:" }
                QQC2.TextField { id:geminiModelField; Kirigami.FormData.label:"Modelo:"; Layout.preferredWidth:280 }
            }
            // OpenAI
            Kirigami.FormLayout {
                Kirigami.InlineMessage { Layout.fillWidth:true;visible:true;type:Kirigami.MessageType.Information;text:"platform.openai.com → API keys" }
                ProviderKeyRow { id:openaiKeyField; Kirigami.FormData.label:"API Key:" }
                QQC2.TextField { id:openaiModelField; Kirigami.FormData.label:"Modelo:"; Layout.preferredWidth:280 }
            }
            // Grok
            Kirigami.FormLayout {
                Kirigami.InlineMessage { Layout.fillWidth:true;visible:true;type:Kirigami.MessageType.Information;text:"console.x.ai → API Keys" }
                ProviderKeyRow { id:grokKeyField; Kirigami.FormData.label:"API Key:" }
                QQC2.TextField { id:grokModelField; Kirigami.FormData.label:"Modelo:"; Layout.preferredWidth:280 }
            }
            // Qwen
            Kirigami.FormLayout {
                Kirigami.InlineMessage { Layout.fillWidth:true;visible:true;type:Kirigami.MessageType.Information;text:"dashscope.aliyun.com → API Key" }
                ProviderKeyRow { id:qwenKeyField; Kirigami.FormData.label:"API Key:" }
                QQC2.TextField { id:qwenModelField; Kirigami.FormData.label:"Modelo:"; Layout.preferredWidth:280 }
            }
            // Ollama
            ColumnLayout {
                spacing:12
                Kirigami.FormLayout {
                    Kirigami.InlineMessage { Layout.fillWidth:true;visible:true;type:Kirigami.MessageType.Information; text:"Ollama debe estar corriendo localmente." }
                    QQC2.TextField { id:ollamaHostField; Kirigami.FormData.label:"Host:"; Layout.preferredWidth:280; placeholderText:"http://localhost:11434" }
                }
                Rectangle {
                    Layout.fillWidth:true
                    implicitHeight: ollamaCol.implicitHeight+16
                    color:"transparent"; border.color:Kirigami.Theme.disabledTextColor; border.width:0.5; radius:6
                    ColumnLayout {
                        id: ollamaCol
                        anchors { left:parent.left;right:parent.right;top:parent.top;margins:8 }
                        spacing:4
                        QQC2.Label { text:"Perfiles Ollama"; font.pixelSize:12; font.weight:Font.Medium; opacity:0.7 }
                        Repeater {
                            model: ollamaModel
                            delegate: RowLayout {
                                Layout.fillWidth:true; spacing:4
                                QQC2.TextField { Layout.preferredWidth:110; text:model.pname; onEditingFinished: { ollamaModel.setProperty(index,"pname",text); configRoot.saveOllamaProfiles() } }
                                QQC2.TextField { Layout.fillWidth:true; text:model.pmodel; onEditingFinished: { ollamaModel.setProperty(index,"pmodel",text); configRoot.saveOllamaProfiles() } }
                                QQC2.Button { text:"✕"; implicitWidth:28; implicitHeight:28; onClicked: { ollamaModel.remove(index); configRoot.saveOllamaProfiles() } }
                            }
                        }
                        QQC2.Button { Layout.fillWidth:true; text:"+ Añadir perfil"; onClicked: { ollamaModel.append({pname:"nuevo",pmodel:""}); configRoot.saveOllamaProfiles() } }
                    }
                }
            }
            // HuggingFace
            Kirigami.FormLayout {
                Kirigami.InlineMessage { Layout.fillWidth:true;visible:true;type:Kirigami.MessageType.Information;text:"huggingface.co → Settings" }
                ProviderKeyRow { id:hfKeyField; Kirigami.FormData.label:"API Key:" }
                QQC2.TextField { id:hfModelField; Kirigami.FormData.label:"Modelo:"; Layout.preferredWidth:280 }
            }
            // === NVIDIA - Optimizado para API gratuita ===
            Kirigami.FormLayout {
                Kirigami.InlineMessage {
                    Layout.fillWidth:true
                    visible:true
                    type:Kirigami.MessageType.Information
                    text:"build.nvidia.com → API Keys (gratuita - ~40 req/min)"
                }
                ProviderKeyRow { id:nvidiaKeyField; Kirigami.FormData.label:"API Key:" }
                QQC2.TextField {
                    id:nvidiaModelField
                    Kirigami.FormData.label:"Modelo:"
                    Layout.preferredWidth:280
                    placeholderText: "meta/llama-3.3-70b-instruct"
                    text: "meta/llama-3.3-70b-instruct"
                }
                QQC2.TextField {
                    id:nvidiaBaseUrlField
                    Kirigami.FormData.label:"Base URL:"
                    Layout.preferredWidth:280
                    text: "https://integrate.api.nvidia.com"
                    placeholderText: "https://integrate.api.nvidia.com"
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.pixelSize: 10
                    opacity: 0.7
                    text: "Modelos recomendados para cuenta gratuita:\n• meta/llama-3.3-70b-instruct (recomendado)\n• nvidia/llama-3.1-nemotron-70b-instruct\n• deepseek-ai/deepseek-r1"
                }
            }
            // OpenRouter
            Kirigami.FormLayout {
                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    visible: true
                    type: Kirigami.MessageType.Information
                    text: "openrouter.ai → Keys (soporta 300+ modelos, tier gratuito disponible)"
                }
                ProviderKeyRow { id: openrouterKeyField; Kirigami.FormData.label: "API Key:" }
                QQC2.TextField {
                    id: openrouterModelField
                    Kirigami.FormData.label: "Modelo:"
                    Layout.preferredWidth: 280
                    placeholderText: "google/gemma-3-27b-it:free"
                    text: "google/gemma-3-27b-it:free"
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.pixelSize: 10
                    opacity: 0.7
                    text: "Sufijo :free para modelos gratuitos.
Ejemplos: meta-llama/llama-4-scout:free, deepseek/deepseek-r1:free"
                }
            }
            // llama.cpp
            Kirigami.FormLayout {
                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    visible: true
                    type: Kirigami.MessageType.Information
                    text: "llama-server local — endpoint OpenAI compatible. No requiere API key."
                }
                QQC2.TextField {
                    id: llamacppHostField
                    Kirigami.FormData.label: "Host:"
                    Layout.preferredWidth: 280
                    placeholderText: "http://localhost:8082"
                    text: "http://localhost:8082"
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.pixelSize: 10
                    opacity: 0.7
                    text: "El modelo lo fija el servidor al arrancar (--model).
Ejemplo de servicio: llama-server --model modelo.gguf --port 8082 --host 0.0.0.0"
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // --- SECCIÓN 3: PROMPTS RÁPIDOS ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            QQC2.Label { text: "Prompts rápidos"; font.pixelSize: 13; font.weight: Font.Medium }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: quickCol.implicitHeight + 16
                color: "transparent"; border.color: Kirigami.Theme.disabledTextColor; border.width: 0.5; radius: 6
                ColumnLayout {
                    id: quickCol
                    anchors { left:parent.left; right:parent.right; top:parent.top; margins:8 }
                    spacing: 6
                    Repeater {
                        model: quickModel
                        delegate: ColumnLayout {
                            Layout.fillWidth: true; spacing: 4
                            RowLayout {
                                spacing: 4
                                QQC2.TextField { Layout.preferredWidth: 110; text: model.plabel; onEditingFinished: { quickModel.setProperty(index, "plabel", text); configRoot.saveQuickPrompts() } }
                                QQC2.TextField { Layout.fillWidth: true; text: model.pprompt; onEditingFinished: { quickModel.setProperty(index, "pprompt", text); configRoot.saveQuickPrompts() } }
                                QQC2.Button { text: "✕"; implicitWidth: 28; implicitHeight: 28; onClicked: { quickModel.remove(index); configRoot.saveQuickPrompts() } }
                            }
                        }
                    }
                    QQC2.Button { Layout.fillWidth: true; text: "+ Añadir prompt"; onClicked: { quickModel.append({plabel:"Nuevo", pprompt:""}); configRoot.saveQuickPrompts() } }
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // --- SECCIÓN 4: BÚSQUEDA WEB ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            RowLayout {
                QQC2.CheckBox {
                    id: searchToggle
                    text: "Habilitar Búsqueda Web"
                    font.weight: Font.Medium
                }
                Kirigami.Icon {
                    source: "network-wired"
                    implicitWidth: 16; implicitHeight: 16
                    opacity: 0.6
                }
            }
            Kirigami.FormLayout {
                visible: searchToggle.checked
                Layout.fillWidth: true
                QQC2.TextField {
                    id: searxngField
                    Kirigami.FormData.label: "Servidor SearXNG:"
                    placeholderText: "http://192.168.1.XX:8080"
                    Layout.fillWidth: true
                }
                QQC2.SpinBox {
                    id: searchLimitSpin
                    Kirigami.FormData.label: "Resultados:"
                    from: 1; to: 10; value: 3
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap; font.pixelSize: 10; opacity: 0.6
                    text: "Se consultará SearXNG para incluir contexto actualizado en tus preguntas."
                }
            }
        }

        Item { implicitHeight: 16 }
        } // fin ColumnLayout
    } // fin ScrollView

    component ProviderKeyRow: RowLayout {
        property alias text: keyInput.text
        spacing: 6
        QQC2.TextField {
            id: keyInput
            Layout.preferredWidth: 220
            echoMode: revealBtn.checked ? TextInput.Normal : TextInput.Password
        }
        QQC2.Button { id:revealBtn; checkable:true; text: checked?"Ocultar":"Mostrar" }
    }
}
