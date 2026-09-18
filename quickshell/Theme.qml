pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: theme

    // Neutral OLED Deep Black Palette (Pure dark neutrals with subtle theme accent)
    property var colors: ({
        "bg": "#000000",
        "card_bg": "#0e0e12",
        "hover_bg": "#18181c",
        "border": "#1a1a20",
        "border_hover": "#26262e",
        "text_primary": "#f8fafc",
        "text_secondary": "#94a3b8",
        "text_muted": "#64748b",
        "accent": "#7aa2f7",
        "error": "#f87171",
        "warning": "#fbbf24"
    })

    property string currentThemeName: "default"
    property string activeTransition: "simple"

    signal themeReloaded()

    function reload() {
        if (themeLoader.running) themeLoader.running = false;
        themeLoader.running = true;
        
        if (themeNameLoader.running) themeNameLoader.running = false;
        themeNameLoader.running = true;

        if (transitionLoader.running) transitionLoader.running = false;
        transitionLoader.running = true;
    }

    Component.onCompleted: theme.reload()

    property Timer pollTimer: Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: theme.reload()
    }

    property Process themeLoader: Process {
        running: false
        command: ["sh", "-c", "cat $HOME/.config/active-theme/quickshell-colors.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    var parsed = JSON.parse(this.text);
                    var acc = parsed.accent || "#7aa2f7";
                    theme.colors = {
                        "bg": "#000000",
                        "card_bg": "#0e0e12",
                        "hover_bg": "#18181c",
                        "border": "#1a1a20",
                        "border_hover": "#26262e",
                        "text_primary": "#f8fafc",
                        "text_secondary": "#94a3b8",
                        "text_muted": "#64748b",
                        "accent": acc,
                        "error": parsed.error || "#f87171",
                        "warning": parsed.warning || "#fbbf24"
                    };
                    theme.themeReloaded();
                } catch(e) {
                    console.warn("[Quickshell Theme] Failed to parse JSON:", e);
                }
            }
        }
    }

    property Process themeNameLoader: Process {
        running: false
        command: ["sh", "-c", "cat $HOME/.config/active-theme/theme-name.txt 2>/dev/null || echo 'default'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var name = this.text.trim();
                if (name !== "") theme.currentThemeName = name;
            }
        }
    }

    property Process transitionLoader: Process {
        running: false
        command: ["sh", "-c", "cat $HOME/.config/active-theme/wallpaper-transition.txt 2>/dev/null || echo 'simple'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var trans = this.text.trim();
                if (trans !== "") theme.activeTransition = trans;
            }
        }
    }
}
