function fish_greeting
    set krabby_cmd ~/.local/bin/krabby
    if command -v fastfetch &> /dev/null && test -x $krabby_cmd
        $krabby_cmd random --no-title | fastfetch --logo-type file-raw --logo -
    else if command -v fastfetch &> /dev/null
        fastfetch
    end
end
