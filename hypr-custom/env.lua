-- Lokalnie: NVIDIA (VA-API i GLX przez sterownik własnościowy), tylko gdy
-- moduł jest załadowany, więc na maszynach z samym AMD nic się nie dzieje.
local nvidia = io.open("/proc/driver/nvidia/version")
if nvidia then
    nvidia:close()
    hl.env("LIBVA_DRIVER_NAME",         "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND",               "direct")
end
