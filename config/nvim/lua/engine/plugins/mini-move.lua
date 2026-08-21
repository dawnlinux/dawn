return {
	"echasnovski/mini.move",
	version = false,
	event = { "BufReadPre", "BufNewFile" },
	-- Defaults: <M-h/j/k/l> moves the visual selection, or the current line in
	-- normal mode. The visual J/K maps in core/keymaps.lua stay as they are.
	opts = {},
}
