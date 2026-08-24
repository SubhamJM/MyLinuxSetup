require("vim._core.ui2").enable({
	enable = true,
	msg = {
		target = "cmd",
		paper = { height = 0.5 },
		dialog = { height = 0.5 },
		cmd = { height = 0.5 },
		msg = { height = 0.5, timeout = 4500 },
	},
})

require("core.keymaps")
require("core.options")
require("plugins.colortheme")
require("plugins.neotree")
require("plugins.bufferline")
require("plugins.lualine")
require("plugins.treesitter")
require("plugins.telescope")
require("plugins.lsp")
require("plugins.snippets")
require("plugins.blink")
require("plugins.pairs")
require("plugins.autoformatting")
require("plugins.autosave")
require("plugins.alpha")
require("plugins.terminal")
require("plugins.copilot")
