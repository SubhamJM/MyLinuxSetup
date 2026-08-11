vim.pack.add({
    { src = "https://github.com/Saghen/blink.cmp" },
})

require("blink.cmp").setup({
    keymap = {
        ["<Tab>"] = { "select_next", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
        ["<CR>"] = { "accept", "fallback" },
        ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
    },

    appearance = {
        nerd_font_variant = "mono",
    },

    completion = {

        documentation = {
            auto_show = true,
            auto_show_delay_ms = 150,
        },

        menu = {
            auto_show = true,
        },
    },

    signature = {
        enabled = true,
    },

    snippets = {
        preset = "luasnip",
    },

    sources = {

        default = {

            "lsp",

            "snippets",

            "path",

            "buffer",
        },
    },

    fuzzy = {
        implementation = "prefer_rust_with_warning",
    },
})
