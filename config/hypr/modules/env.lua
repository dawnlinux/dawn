-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- GPU and driver hints are deliberately NOT set here. LIBVA_DRIVER_NAME,
-- AQ_DRM_DEVICES, NVIDIA's WLR_* flags and friends are all statements about
-- one machine's hardware, and getting them wrong costs you hardware video
-- decode or a working session. Put them in modules/local.lua.
