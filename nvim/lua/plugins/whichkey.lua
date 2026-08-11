vim.pack.add({
	{
		src = "https://github.com/folke/which-key.nvim",
	},
})

local wk = require("which-key")

wk.setup({
	preset = "modern",

	delay = 300,

	notify = true,

	plugins = {
		spelling = {
			enabled = true,
		},
	},

	win = {
		border = "rounded",
		padding = { 1, 2 },
	},

	layout = {
		spacing = 4,
	},

	icons = {
		breadcrumb = "»",
		separator = "➜",
		group = "+",
	},

	show_help = true,
})

wk.add({

    { "<leader>f", group = "Find" },

    { "<leader>e", group = "Explorer" },

    { "<leader>g", group = "Git" },

    { "<leader>l", group = "LSP" },

    { "<leader>t", group = "Terminal" },

    { "<leader>b", group = "Buffers" },

    { "<leader>w", group = "Windows" },

    { "<leader>c", group = "Code" },
})
