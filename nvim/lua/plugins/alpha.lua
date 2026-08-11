vim.pack.add({
	{
		src = "https://github.com/goolord/alpha-nvim",
	},
	{
		src = "https://github.com/nvim-tree/nvim-web-devicons",
	},
})

local alpha = require("alpha")
local dashboard = require("alpha.themes.dashboard")

----------------------------------------------------------
-- Header
----------------------------------------------------------

dashboard.section.header.val = {
	"                                                    ",
	" ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
	" ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
	" ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
	" ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
	" ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
	" ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
	"                                                    ",
	"        Welcome back, Subhamjyoti 🚀                ",
}

----------------------------------------------------------
-- Buttons
----------------------------------------------------------

dashboard.section.buttons.val = {

	dashboard.button("e", "  New File", ":ene <BAR> startinsert<CR>"),

	dashboard.button("f", "󰈞  Find File", ":Telescope find_files<CR>"),

	dashboard.button("r", "  Recent Files", ":Telescope oldfiles<CR>"),

	dashboard.button("g", "󰈬  Live Grep", ":Telescope live_grep<CR>"),

	dashboard.button("c", "  Configuration", ":e $MYVIMRC<CR>"),

	dashboard.button("q", "󰗼  Quit", ":qa<CR>"),
}

----------------------------------------------------------
-- Footer
----------------------------------------------------------

dashboard.section.footer.val = {
	"",
	"⚡ Happy Coding!",
}

----------------------------------------------------------
-- Layout
----------------------------------------------------------

dashboard.config.layout = {
	{ type = "padding", val = 2 },
	dashboard.section.header,
	{ type = "padding", val = 2 },
	dashboard.section.buttons,
	{ type = "padding", val = 1 },
	dashboard.section.footer,
}

alpha.setup(dashboard.config)
