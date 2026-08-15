# source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

if status is-interactive
	set fish_greeting
	fastfetch
end
zoxide init fish | source
starship init fish | source
