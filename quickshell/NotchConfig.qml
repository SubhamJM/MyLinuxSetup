pragma Singleton
import QtQuick

QtObject {
    id: config

    // ==========================================
    // 1. GLOBAL MOTION CURVES & EASINGS
    // ==========================================
    // Caelestia / Material 3 emphasized-decelerate: cubic-bezier(0.05, 0.7, 0.1, 1)
    readonly property var motionCurve: [0.05, 0.7, 0.1, 1, 1, 1]

    // ==========================================
    // 2. GLOBAL ANIMATION DURATIONS (ms)
    // ==========================================
    readonly property int animNotchResize: 400      // Width / height transition of the notch surface
    readonly property int animDashFade: 90          // Quick cross-fade for the persistent dash bar
    readonly property int animModulesFade: 100      // Cross-fade for the expanded module body
    readonly property int animColor: 150            // Standard button & hover color transitions
    readonly property int animScale: 140            // Quick press/hover scale transitions

    // ==========================================
    // 3. AUTO-COLLAPSE & POPUP TIMERS (ms)
    // ==========================================
    readonly property int timerAutoCollapse: 60     // Delay before collapsing after mouse leave
    readonly property int timerNotifPopup: 1600     // How long the notification popup island remains visible
    readonly property int timerStartupGrace: 800    // Grace window on startup to suppress notification replays
    readonly property int timerOsdSettle: 150       // OSD transition settle debounce
    readonly property int timerOsdHide: 1200        // Inactivity timeout to auto-hide OSD bar
    readonly property int timerWorkspacePeek: 1500  // Duration to show workspaces on workspace switch
    readonly property int timerPollOsd: 50          // Frequency to check /tmp/notch_osd
    readonly property int timerBtPopup: 1500        // Duration for Bluetooth connect island popup
    readonly property int timerPowerPopup: 1500     // Duration for Power/Charging connected island popup
    readonly property int timerNetPopup: 1500       // Duration for Network handoff island popup
    readonly property int timerIslandText: 3500     // Duration for Island textual info labels

    // ==========================================
    // 4. STATIC NOTCH BASE DIMENSIONS
    // ==========================================
    readonly property int cornerCurveRadius: 12     // Outer inverse wing curves radius
    readonly property int baseExclusiveZone: 30     // Wayland layer shell exclusive reservation

    readonly property var modeDimensions: ({
        "idle":          { width: 120, height: 30,  radius: 12 },
        "hover":         { width: 460, height: 46,  radius: 12 },
        "launcher":      { width: 460, height: 360, radius: 12 },
        "theme":         { width: 440, height: 280, radius: 12 },
        "wallpaper":     { width: 760, height: 320, radius: 12 },
        "transition":    { width: 440, height: 320, radius: 12 },
        "osd":           { width: 280, height: 40,  radius: 16 },
        "wifi":          { width: 420, height: 380, radius: 12 }, 
        "bluetooth":     { width: 400, height: 360, radius: 12 },
        "recorder":      { width: 380, height: 225, radius: 12 },
        "battery":       { width: 440, height: 220, radius: 12 },
        "powermenu":     { width: 440, height: 100, radius: 14 },
        "calendar":      { width: 320, height: 280, radius: 12 },
        "clipboard":     { width: 460, height: 380, radius: 12 },
        "shelf":         { width: 460, height: 380, radius: 12 },
        "notifications": { width: 440, height: 380, radius: 12 }
    })

    // ==========================================
    // 5. DYNAMIC HEIGHT CALCULATORS
    // ==========================================
    // Notification banner active in Dash mode
    readonly property int heightNotifBanner: 54

    // Dynamic Module Heights (Min / Max bounds and per-item multipliers)
    function calculateNotificationsHeight(count) {
        if (count === 0) return 200;
        return Math.min(480, Math.max(200, 50 + (count * 76)));
    }

    function calculateShelfHeight(count) {
        if (count === 0) return 220;
        return Math.min(440, Math.max(180, 66 + (count * 48)));
    }

    function calculateClipboardHeight(count) {
        if (count === 0) return 220;
        return Math.min(440, Math.max(180, 66 + (count * 48)));
    }

    function calculateLauncherHeight(count, allAppsLength) {
        if (count === 0 && allAppsLength === 0) return 320;
        return Math.min(420, Math.max(160, 66 + (count * 48)));
    }

    function calculateRecorderHeight(recordAudio, isDropdownOpen) {
        if (!recordAudio) return 205;
        if (isDropdownOpen) return 240 + Math.min(3, 4) * 32;
        return 245;
    }

    function calculateBluetoothHeight(devices, stateMap) {
        var btCount = devices.length;
        if (btCount === 0) return 266;

        var listItemsHeight = 0;
        for (var i = 0; i < btCount; i++) {
            var dev = devices[i];
            var expanded = stateMap[dev.mac] && stateMap[dev.mac].isExpanded;
            listItemsHeight += (expanded ? 84 : 48) + 6;
        }
        return Math.min(486, Math.max(246, 112 + listItemsHeight));
    }

    function calculateWifiHeight(activeTab, wifiEnabled, modelCount, listContentHeight) {
        if (activeTab === "hotspot") return 400;
        if (!wifiEnabled) return 226;
        if (modelCount === 0) return 286;
        return Math.min(380, Math.max(240, 120 + listContentHeight));
    }
}
