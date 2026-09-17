import QtQuick
import Quickshell
import Quickshell.Io

// Inir Cava audio visualizer process wrapper
Item {
    id: root
    
    property bool active: false
    property int bars: 5
    property var points: []
    property real normalizationCeiling: 100
    property bool audioSignalActive: false
    
    Process {
        id: cavaProc
        running: root.active
        command: [Quickshell.env("HOME") + "/.config/quickshell/my_own/scripts/cava_runner.sh"]
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (!root.active) return;
                var raw = data.trim();
                if (raw.length === 0) return;
                
                var fields = raw.split(";");
                var pts = [];
                var peak = 0;
                var sum = 0;
                
                for (var i = 0; i < fields.length; i++) {
                    if (fields[i] === "") continue;
                    var v = parseFloat(fields[i]);
                    if (!isNaN(v)) {
                        pts.push(v);
                        peak = Math.max(peak, v);
                        sum += v;
                    }
                }
                
                if (pts.length >= root.bars) {
                    root.points = pts.slice(0, root.bars);
                    
                    var targetCeil = Math.max(20, peak * 1.15);
                    if (targetCeil >= root.normalizationCeiling) {
                        root.normalizationCeiling = targetCeil;
                    } else {
                        root.normalizationCeiling = Math.max(20, root.normalizationCeiling * 0.99);
                    }
                    root.audioSignalActive = (peak >= 2) || ((sum / root.bars) >= 0.35);
                }
            }
        }
    }
    
    // Reset when inactive
    onActiveChanged: {
        if (!active) {
            points = [];
            normalizationCeiling = 100;
            audioSignalActive = false;
        }
    }
}
