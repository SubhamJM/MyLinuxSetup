#!/usr/bin/env bash

case "$1" in
    volume_up)
        wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
        VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}')
        echo "volume $VOL" > /tmp/notch_osd
        ;;
    volume_down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}')
        echo "volume $VOL" > /tmp/notch_osd
        ;;
    volume_mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        MUTED=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -o "MUTED")
        if [ "$MUTED" = "MUTED" ]; then
            echo "volume 0" > /tmp/notch_osd
        else
            VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}')
            echo "volume $VOL" > /tmp/notch_osd
        fi
        ;;
    brightness_up)
        brightnessctl set +5%
        BRIGHT=$(brightnessctl i | grep -oP '\(\K[0-9]+(?=%\))')
        echo "brightness $BRIGHT" > /tmp/notch_osd
        ;;
    brightness_down)
        brightnessctl set 5%-
        BRIGHT=$(brightnessctl i | grep -oP '\(\K[0-9]+(?=%\))')
        echo "brightness $BRIGHT" > /tmp/notch_osd
        ;;
    kbd_up)
        brightnessctl --device='*kbd_backlight*' set +10%
        BRIGHT=$(brightnessctl --device='*kbd_backlight*' i | grep -oP '\(\K[0-9]+(?=%\))')
        echo "brightness $BRIGHT" > /tmp/notch_osd
        ;;
    kbd_down)
        brightnessctl --device='*kbd_backlight*' set 10%-
        BRIGHT=$(brightnessctl --device='*kbd_backlight*' i | grep -oP '\(\K[0-9]+(?=%\))')
        echo "brightness $BRIGHT" > /tmp/notch_osd
        ;;
esac
