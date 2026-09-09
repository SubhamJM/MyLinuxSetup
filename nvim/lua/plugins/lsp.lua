------------------------------------------------------------
-- Lua
------------------------------------------------------------

vim.lsp.config("lua_ls", {
	settings = {
		Lua = {
			runtime = {
				version = "LuaJIT",
			},

			diagnostics = {
				globals = { "vim" },
			},

			workspace = {
				checkThirdParty = false,
				library = vim.api.nvim_get_runtime_file("", true),
			},

			telemetry = {
				enable = false,
			},
		},
	},
})

------------------------------------------------------------
-- Python
------------------------------------------------------------

local capabilities = vim.lsp.protocol.make_client_capabilities()
-- Enable didChangeWatchedFiles dynamic registration
capabilities.workspace = capabilities.workspace or {}
capabilities.workspace.didChangeWatchedFiles = {
    dynamicRegistration = true,
}

-- If using blink.cmp capabilities helper:
if pcall(require, "blink.cmp") then
    capabilities = require("blink.cmp").get_lsp_capabilities(capabilities)
end

vim.lsp.config("pyright", {
    cmd = { "pyright-langserver", "--stdio" },
    filetypes = { "python" },
    root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
    capabilities = capabilities,
    settings = {
        python = {
            pythonPath = vim.fn.getcwd() .. "/.venv/bin/python",
            analysis = {
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "workspace",
            },
        },
    },
})

vim.keymap.set("n", "<leader>lr", "<cmd>lsp restart<cr>", { desc = "Restart LSP" })


------------------------------------------------------------
-- C / C++
------------------------------------------------------------

vim.lsp.config("clangd", {})

------------------------------------------------------------
-- Java
------------------------------------------------------------

vim.lsp.config("jdtls", {
    cmd = { "/usr/bin/jdtls" },
})

------------------------------------------------------------
-- JavaScript / TypeScript
------------------------------------------------------------

vim.lsp.config("ts_ls", {})

------------------------------------------------------------
-- HTML
------------------------------------------------------------

vim.lsp.config("html", {})

------------------------------------------------------------
-- CSS
------------------------------------------------------------

vim.lsp.config("cssls", {})

------------------------------------------------------------
-- Rust
------------------------------------------------------------

vim.lsp.config("rust_analyzer", {})

------------------------------------------------------------
-- Go
------------------------------------------------------------

vim.lsp.config("gopls", {})

------------------------------------------------------------
-- Enable servers
------------------------------------------------------------

vim.lsp.enable({
	"lua_ls",
	"pyright",
	"clangd",
	"jdtls",
	"ts_ls",
	"html",
	"cssls",
	"rust_analyzer",
	"gopls",
})

------------------------------------------------------------
-- LSP Keymaps
------------------------------------------------------------

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(event)
		local opts = { buffer = event.buf }

		vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
		vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
		vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
		vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
		vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)

		vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
		vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)

		vim.keymap.set("n", "<leader>f", function()
			vim.lsp.buf.format({ async = true })
		end, opts)
	end,
})

------------------------------------------------------------
-- Diagnostics
------------------------------------------------------------

vim.diagnostic.config({
	virtual_text = true,
	signs = true,
	underline = true,
	severity_sort = true,
	update_in_insert = false,
})
