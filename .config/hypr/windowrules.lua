h1.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },

	suppress_event = "maximize",
})

h1.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class 			= "^$",
		title 			= "^$",
		xwayland 		= true,
		float 			= true,
		fullscreen 	= false,
		pin 				= false,
	},

	no_foucs = true,
})

h1.layer_rule({
	name = "rofi-dropdown",
	match = { namespace = "rofi" },
	animation = "slide bottom",
	dim_around = true,
})
