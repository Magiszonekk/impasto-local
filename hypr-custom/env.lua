-- Local: NVIDIA (VA-API and GLX through the proprietary driver), only when the
-- module is loaded, so on AMD-only machines nothing happens.
local nvidia = io.open("/proc/driver/nvidia/version")
if nvidia then
    nvidia:close()
    hl.env("LIBVA_DRIVER_NAME",         "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND",               "direct")
end
