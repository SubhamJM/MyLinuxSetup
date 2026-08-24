vim.pack.add({
	{ src = "https://github.com/github/copilot.vim"},
})

-- Disable default Tab mapping if needed and configure keymaps
vim.g.copilot_no_tab_map = true

local map = vim.keymap.set
local opts = { expr = true, silent = true, replace_keycodes = false }

-- Accept inline ghost text suggestion (<C-l>)
map("i", "<C-l>", 'copilot#Accept("<CR>")', opts)

-- Cycle through alternate suggestions
map("i", "<M-]>", "<Plug>(copilot-next)", { silent = true })
map("i", "<M-[>", "<Plug>(copilot-previous)", { silent = true })

-- Dismiss the current suggestion
map("i", "<C-]>", "<Plug>(copilot-dismiss)", { silent = true })


local copilot_active = true

local function toggle_copilot()
  if copilot_active then
    vim.cmd("Copilot disable")
    copilot_active = false
    vim.notify("Copilot disabled", vim.log.levels.WARN)
  else
    vim.cmd("Copilot enable")
    copilot_active = true
    vim.notify("Copilot enabled", vim.log.levels.INFO)
  end
end

-- Toggle Copilot globally in Normal mode (<leader>ct)
vim.keymap.set("n", "<leader>q", toggle_copilot, { desc = "Toggle Copilot" })
