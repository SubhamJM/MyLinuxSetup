-- Catppuccin
vim.pack.add({
	{
		src = "https://github.com/catppuccin/nvim",
		name = "catppuccin",
	},
})

local transparent = true

local function toggle_transparency()
	transparent = not transparent

	require("catppuccin").setup({
		flavour = "mocha",
		transparent_background = transparent,

		no_italic = true,

		integrations = {
			treesitter = true,
			native_lsp = { enabled = true },
			telescope = true,
			neotree = true,
			cmp = true,
			gitsigns = true,
		},
	})

	vim.cmd.colorscheme("catppuccin")
end

--vim.keymap.set("n", "bg", toggle_transparency, {
--noremap = true,
--	silent = true,
--desc = "Toggle background transparency",
--})

require("catppuccin").setup({
	flavour = "mocha", -- latte, frappe, macchiato, mocha

	transparent_background = transparent,

	styles = {
		comments = {},
		conditionals = { "bold" },
		loops = { "bold" },
		functions = { "bold" },
		keywords = { "bold" },
		types = { "bold" },
	},

	term_colors = true,

	no_italic = false,
	no_bold = false,
	no_underline = false,

	dim_inactive = {
		enabled = false,
	},

	integrations = {
		treesitter = true,
		native_lsp = {
			enabled = true,
		},
		telescope = true,
		neotree = true,
		cmp = true,
		gitsigns = true,
		markdown = true,
	},

	color_overrides = {
		mocha = {
			-- Example: make text slightly brighter
			text = "#ffffff",
		},
	},

	highlight_overrides = {
		mocha = function(colors)
			return {
				Function = { fg = colors.blue, bold = true },
				Keyword = { fg = colors.mauve, bold = true },
				Type = { fg = colors.yellow, bold = true },
				String = { fg = colors.green },
				Comment = { fg = colors.overlay1, italic = true },
				Constant = { fg = colors.peach },
			}
		end,
	},
})

vim.cmd.colorscheme("catppuccin")
