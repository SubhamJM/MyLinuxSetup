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

    -- Inject arguments into the external formatters
    formatters = {
        prettier = {
            prepend_args = { "--tab-width", "4" },
        },
        stylua = {
            prepend_args = { "--indent-type", "Spaces", "--indent-width", "4" },
        },
        clang_format = {
            -- Uses 4 spaces as a fallback, but allows project .clang-format files to override
            prepend_args = { "-fallback-style={IndentWidth: 4}" },
        },
        ["google-java-format"] = {
            -- Google Java Format strictly enforces 2 spaces. 
            -- The --aosp (Android Open Source Project) flag is the only way to force it to 4 spaces.
            prepend_args = { "--aosp" },
        },
    },

    format_on_save = function(bufnr)
        return {
            timeout_ms = 500,
            lsp_fallback = true,
        }
    end,
})
