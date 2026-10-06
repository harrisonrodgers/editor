-- shellRaining/hlchunk.nvim
local c = _G.selenized.colors
local tint = require("config/tint")
local BLANK_TINT = 0.05 -- strength of the per-level indent backgrounds (0 = editor background, 1 = full color)

require("hlchunk").setup({
	chunk = {
		enable = false,
		use_treesitter = true,
		style = {
			{ fg = c.violet }, -- normal chunk
			{ fg = c.red }, -- chunk containing a syntax error
		},
		textobject = "ic", -- e.g. `dic`, `vic`, `yic` operate on the current chunk
		delay = 0, -- disable animation
	},

	indent = {
		enable = false,
		-- false: take each line's indent from its whitespace. With treesitter, lines inside a multi-line string (a
		-- python docstring) get indent 0 from nvim-treesitter's indent rules, so no guides were drawn there.
		use_treesitter = false,
		chars = { "¦" },
		style = { { fg = c.fg_2, bg = nil } }, -- TODO: try the default and see if that looks good (it's "whitespace" from theme)
	},

	line_num = {
		enable = true,
		use_treesitter = true,
		style = { { fg = c.fg_1, bg = tint(c.fg_1, c.bg_0, 0.15) } }, -- must be a list of tables to accept bg
	},

	blank = {
		enable = false,
		chars = {
			"    ",
		},
		-- one background per indent level, each a tint of the color over the editor background (raise BLANK_TINT for stronger)
		style = {
			{ bg = tint(c.green, c.bg_0, BLANK_TINT) },
			{ bg = tint(c.blue, c.bg_0, BLANK_TINT) },
			{ bg = tint(c.cyan, c.bg_0, BLANK_TINT) },
			{ bg = tint(c.violet, c.bg_0, BLANK_TINT) },
			{ bg = tint(c.magenta, c.bg_0, BLANK_TINT) },
			{ bg = tint(c.orange, c.bg_0, BLANK_TINT) },
			{ bg = tint(c.red, c.bg_0, BLANK_TINT) },
		},
	},
})

-- TODO: configure to preference, https://github.com/shellRaining/hlchunk.nvim
