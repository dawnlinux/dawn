--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------


hl.window_rule({
	-- Ignore maximize requests from all apps. You'll probably like this.
	name           = "suppress-maximize-events",
	match          = { class = ".*" },

	suppress_event = "maximize",
})

hl.window_rule({
	-- Fix some dragging issues with XWayland
	name     = "fix-xwayland-drags",
	match    = {
		class      = "^$",
		title      = "^$",
		xwayland   = true,
		float      = true,
		fullscreen = false,
		pin        = false,
	},

	no_focus = true,
})

hl.layer_rule({
	name = "notification-animation",
	match = { namespace = "swaync-control-center" },
	animation = "slide-top",
})

hl.window_rule({
	name      = "float-bluetui",
	match     = { class = "^(floating-bluetui)$" },
	float     = true,
	size      = { 600, 450 },
	move      = { "(monitor_w/2)-(window_w/2)", "(monitor_h/2)-(window_h/2)" },
	rounding  = 12,
	animation = "popin",
})

hl.window_rule({
	name      = "float-btop",
	match     = { class = "^(floating-btop)$" },
	float     = true,
	size      = { 800, 550 },
	move      = { "(monitor_w/2)-(window_w/2)", "(monitor_h/2)-(window_h/2)" },
	rounding  = 12,
	animation = "popin",
})

hl.window_rule({
	name      = "float-pavucontrol",
	match     = { class = "^(org.pulseaudio.pavucontrol)$" },
	float     = true,
	size      = { 750, 500 },
	move      = { "(monitor_w/2)-(window_w/2)", "(monitor_h/2)-(window_h/2)" },
	rounding  = 12,
	animation = "popin",
})

hl.window_rule({
	name      = "float-update",
	match     = { class = "^(floating-update)$" },
	float     = true,
	size      = { 700, 500 },
	move      = { "(monitor_w/2)-(window_w/2)", "(monitor_h/2)-(window_h/2)" },
	rounding  = 12,
	animation = "popin",
})
hl.window_rule({
	name      = "float-nmtui",
	match     = { class = "^(floating-nmtui)$" },
	float     = true,
	size      = { 700, 500 },
	move      = { "(monitor_w/2)-(window_w/2)", "(monitor_h/2)-(window_h/2)" },
	rounding  = 12,
	animation = "popin",
})
