vim.pack.add({
	{
		src = "https://github.com/akinsho/toggleterm.nvim",
	},
})

require("toggleterm").setup({

	size = 15,

	open_mapping = nil,

	hide_numbers = true,

	shade_terminals = true,

	shading_factor = 2,

	start_in_insert = true,

	insert_mappings = true,

	persist_size = true,

	persist_mode = true,

	direction = "horizontal",

	close_on_exit = true,

	shell = vim.o.shell,

	float_opts = {
		border = "rounded",
	},
})

----------------------------------------------------
-- Ctrl + ` Toggle Terminal
----------------------------------------------------

vim.keymap.set({ "n", "t" }, "<C-`>", "<cmd>ToggleTerm<CR>", {
	silent = true,
	desc = "Toggle Terminal",
})

----------------------------------------------------
-- Exit terminal mode quickly
----------------------------------------------------

vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], {
	silent = true,
})
