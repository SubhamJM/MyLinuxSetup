vim.pack.add({
	{
		src = "https://github.com/stevearc/conform.nvim",
	},
})

require("conform").setup({
	formatters_by_ft = {
		lua = { "stylua" },

		python = { "isort", "black" },

		c = { "clang_format" },
		cpp = { "clang_format" },

		java = { "google-java-format" },

		javascript = { "prettier" },
		typescript = { "prettier" },

		html = { "prettier" },
		css = { "prettier" },

		json = { "prettier" },
		markdown = { "prettier" },

		rust = { "rustfmt" },

		go = { "goimports", "gofmt" },
	},

	format_on_save = function(bufnr)
		return {
			timeout_ms = 500,
			lsp_fallback = true,
		}
	end,
})
