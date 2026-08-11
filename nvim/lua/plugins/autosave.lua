vim.pack.add({
	{
		src = "https://github.com/okuuva/auto-save.nvim",
	},
})

require("auto-save").setup({
	enabled = true,
	debounce_delay = 500,
})
