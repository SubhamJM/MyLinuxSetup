vim.pack.add({
	"https://github.com/nvim-tree/nvim-web-devicons",
	"https://github.com/akinsho/bufferline.nvim",
	"https://github.com/famiu/bufdelete.nvim",
})

vim.opt.termguicolors = true

require("bufferline").setup({
    options = {
        mode = "buffers",
        themable = true,
        -- auto_toggle_bufferline = true, -- Automatically hides the bar when only 1 buffer / alpha is open
        custom_filter = function(buf_number)
            local ft = vim.bo[buf_number].filetype
            if ft == "alpha" or ft == "dashboard" or ft == "neo-tree" then
                return false
            end
            return true
        end,
        numbers = "none",
        close_command = "Bdelete! %d",
        buffer_close_icon = "✗",
        close_icon = "✗",
        path_components = 1,
        modified_icon = "●",
        left_trunc_marker = "",
        right_trunc_marker = "",
        max_name_length = 30,
        max_prefix_length = 30,
        tab_size = 21,
        diagnostics = false,
        color_icons = true,
        show_buffer_icons = true,
        show_buffer_close_icons = false,
        show_close_icon = false,
        persist_buffer_sort = true,
        separator_style = "thin",
        enforce_regular_tabs = true,
        always_show_bufferline = true,
        show_tab_indicators = false,
        indicator = {
            style = "none",
        },
        icon_pinned = "󰐃",
        minimum_padding = 1,
        maximum_padding = 5,
        maximum_length = 15,
        sort_by = "insert_at_end",
    },
    highlights = {
        fill = {
            bg = "NONE",
        },
        background = {
            fg = "#6c7086",
            bg = "NONE",
        },
        buffer_selected = {
            fg = "#cdd6f4",
            bg = "NONE",
            bold = true,
            italic = false,
        },
        buffer_visible = {
            fg = "#6c7086",
            bg = "NONE",
        },
        close_button = {
            bg = "NONE",
        },
        close_button_visible = {
            bg = "NONE",
        },
        close_button_selected = {
            bg = "NONE",
        },
        tab = {
            bg = "NONE",
        },
        tab_selected = {
            bg = "NONE",
        },
        tab_close = {
            bg = "NONE",
        },
        separator = {
            fg = "#313244",
            bg = "NONE",
        },
        separator_selected = {
            fg = "#313244",
            bg = "NONE",
        },
        separator_visible = {
            fg = "#313244",
            bg = "NONE",
        },
        modified = {
            bg = "NONE",
        },
        modified_visible = {
            bg = "NONE",
        },
        modified_selected = {
            bg = "NONE",
        },
        indicator_selected = {
            fg = "NONE",
            bg = "NONE",
        },
        offset_separator = {
            fg = "#313244",
            bg = "NONE",
        },
    },
})

vim.keymap.set("n", "<Tab>", "<cmd>BufferLineCycleNext<CR>", { desc = "Next Buffer" })
vim.keymap.set("n", "<S-Tab>", "<cmd>BufferLineCyclePrev<CR>", { desc = "Previous Buffer" })
vim.keymap.set("n", "<leader>w", function()
    local current = vim.api.nvim_get_current_buf()
    vim.cmd("bnext")
    if vim.api.nvim_get_current_buf() == current then
        vim.cmd("bprevious")
    end
    vim.cmd("bdelete " .. current)
end, { desc = "Close buffer" })
