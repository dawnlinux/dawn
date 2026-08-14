-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- This is a Haswell (i7-4980HQ / Iris Pro 5200). intel-media-driver's iHD
-- backend only supports Broadwell and newer, so libva picks it, fails with
-- "iHD_drv_video.so init failed", and every video ends up on the CPU.
-- Name the i965 driver explicitly so hardware decode is actually used.
hl.env("LIBVA_DRIVER_NAME", "i965")
