-- Local keybinds (magiszonek). Loaded after the author's modules/keybinds.lua;
-- `setup update` never touches this directory. Copied here by apply.sh.
local mainMod = "SUPER"

-- · applications
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("spotify"), { description = "Applications · Open Spotify" })
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("vesktop"), { description = "Applications · Open Discord (Vesktop)" })
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("kitty --class impasto-btop -e btop"),
        { description = "Applications · Open btop" })

-- · fullscreen without the app knowing (the browser keeps its tabs). The
-- · author's bind has to be removed, since the one from custom/ only runs after it.
hl.unbind(mainMod .. " + F")
hl.bind(mainMod .. " + F",
        hl.dsp.window.fullscreen_state({ internal = 2, client = 0, action = "toggle" }),
        { description = "Windows · Full screen (app unaware, so browser keeps its tabs)" })

-- · resize mode: SUPER+R, then arrows or h/j/k/l, Esc/Enter leaves
local RESIZE_STEP = 40
local function resize_by(x, y)
    return hl.dsp.window.resize({ x = x, y = y, relative = true })
end

hl.bind(mainMod .. " + R", hl.dsp.submap("resize"), { description = "Windows · Resize mode" })

hl.define_submap("resize", function()
    hl.bind("left",  resize_by(-RESIZE_STEP, 0), { repeating = true })
    hl.bind("right", resize_by(RESIZE_STEP, 0),  { repeating = true })
    hl.bind("up",    resize_by(0, -RESIZE_STEP), { repeating = true })
    hl.bind("down",  resize_by(0, RESIZE_STEP),  { repeating = true })
    hl.bind("h",     resize_by(-RESIZE_STEP, 0), { repeating = true })
    hl.bind("l",     resize_by(RESIZE_STEP, 0),  { repeating = true })
    hl.bind("k",     resize_by(0, -RESIZE_STEP), { repeating = true })
    hl.bind("j",     resize_by(0, RESIZE_STEP),  { repeating = true })
    hl.bind(mainMod .. " + R", hl.dsp.submap("reset"))
    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
end)
