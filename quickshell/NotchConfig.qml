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
    readonly property int animNotchResize: 420      // Width / height transition of the notch surface
    readonly property int animDashFade: 90          // Quick cross-fade for the persistent dash bar
    readonly property int animModulesFade: 100      // Cross-fade for the expanded module body
    readonly property int animColor: 150            // Standard button & hover color transitions
    readonly property int animScale: 140            // Quick press/hover scale transitions

    // ==========================================
    // 3. AUTO-COLLAPSE & POPUP TIMERS (ms)
    // ==========================================
    readonly property int timerAutoCollapse: 60     // Delay before collapsing after mouse leave
    readonly property int timerNotifPopup: 1600     // How long the notification popup island remains visible
    readonly property int timerStartupGrace: 600    // Grace window on startup to suppress notification replays
    readonly property int timerOsdSettle: 150       // OSD transition settle debounce
    readonly property int timerOsdHide: 1200        // Inactivity timeout to auto-hide OSD bar
    readonly property int timerWorkspacePeek: 800  // Duration to show workspaces on workspace switch
    readonly property int timerBtPopup: 1500        // Duration for Bluetooth connect island popup
    readonly property int timerPowerPopup: 1500     // Duration for Power/Charging connected island popup
    readonly property int timerNetPopup: 1500       // Duration for Network handoff island popup
    readonly property int timerIslandText: 3500     // Duration for Island textual info labels

    // ==========================================
    // 4. STATIC NOTCH BASE DIMENSIONS
    // ==========================================
    readonly property int cornerCurveRadius: 12     // Outer inverse wing curves radius
    readonly property int baseExclusiveZone: 32     // Wayland layer shell exclusive reservation

    readonly property var modeDimensions: ({
        "idle":          { width: 120, height: 32,  radius: 12 },
		"hover":         { width: 340, height: 46,  radius: 12 },
		"switcher":      { width: 800, height: 420, radius: 14 },
        "launcher":      { width: 460, height: 360, radius: 12 },
        "theme":         { width: 660, height: 200, radius: 14 },
        "wallpaper":     { width: 760, height: 320, radius: 12 },
        "transition":    { width: 440, height: 320, radius: 12 },
        "osd":           { width: 280, height: 40,  radius: 16 },
        "wifi":          { width: 420, height: 380, radius: 12 }, 
        "bluetooth":     { width: 400, height: 360, radius: 12 },
        "recorder":      { width: 380, height: 225, radius: 12 },
        "battery":       { width: 540, height: 435, radius: 18 },
        "powermenu":     { width: 440, height: 100, radius: 14 },
        "calendar":      { width: 320, height: 280, radius: 12 },
        "clipboard":     { width: 460, height: 380, radius: 12 },
        "shelf":         { width: 460, height: 380, radius: 12 },
        "utility":       { width: 440, height: 350, radius: 14 },
        "music":         { width: 440, height: 210, radius: 14 },
        "notes":         { width: 680, height: 480, radius: 14 },
        "cheatsheet":    { width: 800, height: 440, radius: 14 }
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
        var btCount = devices ? devices.length : 0;
        if (btCount === 0) return 266;

        var listItemsHeight = 0;
        for (var i = 0; i < btCount; i++) {
            var dev = devices[i];
            var expanded = stateMap && stateMap[dev.mac] && stateMap[dev.mac].isExpanded;
            listItemsHeight += (expanded ? 88 : 48) + 6;
        }
        // Fixed overhead: shell margins (24) + header (44) + spacing (10) + title row (28) + spacing (10) + list padding (12) = 128px
        return Math.min(486, Math.max(246, 128 + listItemsHeight));
    }

    function calculateWifiHeight(activeTab, wifiEnabled, modelCount, listContentHeight) {
        if (activeTab === "hotspot") return 400;
        if (!wifiEnabled) return 226;
        if (modelCount === 0) return 286;

        // Fixed overhead: shell margins (24) + header (44) + spacing (10) + tab bar (40) + spacing (10) + toggle row (40) + spacing (8) + list padding (10) = 186px
        var overhead = 186;
        var contentH = Math.max(listContentHeight, modelCount * 58);
        return Math.min(380, Math.max(260, overhead + contentH));
    }
}
