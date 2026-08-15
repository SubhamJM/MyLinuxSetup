pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: theme

    property var colors: ({
        "bg": "#16161e",
        "card_bg": "#1f2335",
        "hover_bg": "#24283b",
        "border": "#16161e",
        "border_hover": "#7aa2f7",
        "text_primary": "#c0caf5",
        "text_secondary": "#565f89",
        "accent": "#7aa2f7"
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

    property Timer pollTimer: Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: theme.reload()
    }

    property Process themeLoader: Process {
        running: false
        command: ["sh", "-c", "cat $HOME/.config/active-theme/quickshell-colors.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    theme.colors = JSON.parse(this.text);
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
