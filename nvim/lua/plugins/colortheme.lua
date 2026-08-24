-- 1. Install & Load all colorscheme packages
vim.pack.add({
    { src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
    { src = "https://github.com/ellisonleao/gruvbox.nvim", name = "gruvbox" },
    { src = "https://github.com/folke/tokyonight.nvim", name = "tokyonight" },
    { src = "https://github.com/rose-pine/neovim", name = "rose-pine" },
    { src = "https://github.com/shaunsingh/nord.nvim", name = "nord" },
    { src = "https://github.com/navarasu/onedark.nvim", name = "onedark" },
    { src = "https://github.com/Mofiqul/dracula.nvim", name = "dracula" },
    { src = "https://github.com/neanias/everforest-nvim", name = "everforest" },
    { src = "https://github.com/loctvl842/monokai-pro.nvim", name = "monokai-pro" },
    { src = "https://github.com/Shatur/neovim-ayu", name = "neovim-ayu" },
    { src = "https://github.com/fxn/vim-monochrome", name = "vim-monochrome" },
})

local transparent = true

-- Function to aggressively clear top/bottom bars, window bars, and fill areas
local function enforce_transparency()
    if not transparent then return end

    -- Static global UI groups including winbar and tabline
    local static_groups = {
        "Normal", "NormalNC", "NormalFloat", "FloatBorder", "SignColumn",
        "LineNr", "CursorLineNr", "FoldColumn", "Folded",
        "StatusLine", "StatusLineNC", "MsgArea", "WinSeparator", "VertSplit",
        "TabLine", "TabLineFill", "TabLineSel",
        "WinBar", "WinBarNC",
    }

    for _, group in ipairs(static_groups) do
        vim.api.nvim_set_hl(0, group, { bg = "NONE", ctermbg = "NONE" })
    end

    -- Dynamically catch all BufferLine, TabLine, and WinBar highlight groups
    local all_hl = vim.api.nvim_get_hl(0, {})
    for name, hl in pairs(all_hl) do
        if name:match("^BufferLine") or name:match("^TabLine") or name:match("^WinBar") then
            local new_hl = vim.tbl_extend("force", hl, { bg = "NONE", ctermbg = "NONE" })
            vim.api.nvim_set_hl(0, name, new_hl)
        end
    end
end

-- Hook into every colorscheme load event (scheduled to run after colorscheme finishes setting highlights)
vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
        vim.schedule(enforce_transparency)
    end,
})

local function setup_theme_options()
    -- Catppuccin
    local has_catppuccin, catppuccin = pcall(require, "catppuccin")
    if has_catppuccin then
        catppuccin.setup({
            flavour = "mocha",
            transparent_background = transparent,
            term_colors = true,
            dim_inactive = { enabled = false },
            integrations = { treesitter = true, native_lsp = { enabled = true }, cmp = true, bufferline = false },
        })
    end

    -- Gruvbox
    local has_gruvbox, gruvbox = pcall(require, "gruvbox")
    if has_gruvbox then
        gruvbox.setup({
            transparent_mode = transparent,
            overrides = {
                TabLine = { bg = "NONE" },
                TabLineFill = { bg = "NONE" },
                TabLineSel = { bg = "NONE" },
                StatusLine = { bg = "NONE" },
                StatusLineNC = { bg = "NONE" },
            },
        })
    end

    -- Tokyonight
    local has_tokyo, tokyo = pcall(require, "tokyonight")
    if has_tokyo then
        tokyo.setup({
            transparent = transparent,
            styles = { sidebars = "transparent", floats = "transparent" },
            on_highlights = function(hl, _)
                hl.TabLine = { bg = "NONE" }
                hl.TabLineFill = { bg = "NONE" }
                hl.TabLineSel = { bg = "NONE" }
                hl.StatusLine = { bg = "NONE" }
                hl.StatusLineNC = { bg = "NONE" }
            end,
        })
    end

    -- Rose-pine
    local has_rose, rose = pcall(require, "rose-pine")
    if has_rose then
        rose.setup({ styles = { transparency = transparent } })
    end

    -- Everforest
    vim.g.everforest_transparent_background = transparent and 2 or 0
    vim.g.everforest_background = "hard"

    -- Monokai-Pro
    local has_monokai, monokai = pcall(require, "monokai-pro")
    if has_monokai then
        monokai.setup({ transparent_background = transparent })
    end

    -- Nord
    vim.g.nord_disable_background = transparent

    -- OneDark
    local has_onedark, onedark = pcall(require, "onedark")
    if has_onedark then
        onedark.setup({
            style = "dark",
            transparent = transparent,
        })
    end

    -- Dracula
    local has_dracula, dracula = pcall(require, "dracula")
    if has_dracula then
        dracula.setup({
            transparent_bg = transparent,
        })
    end
end

local function get_active_theme()
    local theme_file = vim.fn.expand("~/.local/state/nvim/active_colorscheme")
    if vim.fn.filereadable(theme_file) == 1 then
        local lines = vim.fn.readfile(theme_file)
        if #lines > 0 and lines[1] ~= "" then
            return vim.trim(lines[1])
        end
    end
    return "catppuccin-mocha"
end

local function apply_custom_theme_highlights(theme)
    if theme == "e-ink" then
        local bg_color = transparent and "NONE" or "#121212"
        local fg_main = "#f5f5f5"
        local fg_muted = "#757575"
        local fg_dim = "#9e9e9e"

        vim.api.nvim_set_hl(0, "Normal", { fg = fg_main, bg = bg_color })
        vim.api.nvim_set_hl(0, "NormalFloat", { fg = fg_main, bg = bg_color })
        vim.api.nvim_set_hl(0, "Comment", { fg = fg_muted, italic = true })
        vim.api.nvim_set_hl(0, "Constant", { fg = fg_main, bold = true })
        vim.api.nvim_set_hl(0, "String", { fg = fg_dim })
        vim.api.nvim_set_hl(0, "Character", { fg = fg_dim })
        vim.api.nvim_set_hl(0, "Identifier", { fg = fg_main })
        vim.api.nvim_set_hl(0, "Function", { fg = fg_main, bold = true })
        vim.api.nvim_set_hl(0, "Statement", { fg = fg_main, bold = true })
        vim.api.nvim_set_hl(0, "Operator", { fg = fg_muted })
        vim.api.nvim_set_hl(0, "Keyword", { fg = fg_main, bold = true })
        vim.api.nvim_set_hl(0, "PreProc", { fg = fg_dim })
        vim.api.nvim_set_hl(0, "Type", { fg = fg_main, bold = true })
        vim.api.nvim_set_hl(0, "Special", { fg = fg_main })
        vim.api.nvim_set_hl(0, "LineNr", { fg = fg_muted })
        vim.api.nvim_set_hl(0, "CursorLineNr", { fg = fg_main, bold = true })
        vim.api.nvim_set_hl(0, "StatusLine", { fg = fg_main, bg = "NONE" })
        vim.api.nvim_set_hl(0, "Visual", { bg = "#383838" })
    elseif theme == "emerald" then
        vim.api.nvim_set_hl(0, "Function", { fg = "#10b981", bold = true })
        vim.api.nvim_set_hl(0, "Keyword", { fg = "#5cd9b2", bold = true })
        vim.api.nvim_set_hl(0, "Type", { fg = "#84cbb9", bold = true })
        vim.api.nvim_set_hl(0, "String", { fg = "#10b981" })
        vim.api.nvim_set_hl(0, "Comment", { fg = "#4e7d6f", italic = true })
    end
end

function _G.reload_active_theme()
    setup_theme_options()
    local current_theme = get_active_theme()

    if current_theme == "e-ink" then
        pcall(vim.cmd.colorscheme, "monochrome")
        apply_custom_theme_highlights("e-ink")
    elseif current_theme == "emerald" then
        pcall(vim.cmd.colorscheme, "everforest")
        apply_custom_theme_highlights("emerald")
    else
        local ok, _ = pcall(vim.cmd.colorscheme, current_theme)
        if not ok then
            pcall(vim.cmd.colorscheme, "catppuccin-mocha")
        end
    end

    enforce_transparency()

    -- Re-link lualine to match new colors
    local has_lualine, lualine = pcall(require, "lualine")
    if has_lualine then
        lualine.setup({ options = { theme = "auto" } })
    end
end

-- Apply on startup
_G.reload_active_theme()

-- Live reload via SIGUSR1
vim.api.nvim_create_autocmd("Signal", {
    pattern = "SIGUSR1",
    callback = function()
        _G.reload_active_theme()
    end,
})

vim.api.nvim_create_user_command("ReloadTheme", _G.reload_active_theme, {})
