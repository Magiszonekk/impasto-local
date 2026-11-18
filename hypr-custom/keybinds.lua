-- Lokalne skróty (magiszonek). Ładowane po modules/keybinds.lua autora,
-- `setup update` tego katalogu nie rusza. Kopiowane tu przez apply.sh.
local mainMod = "SUPER"

-- · aplikacje
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("spotify"), { description = "Applications · Open Spotify" })
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("vesktop"), { description = "Applications · Open Discord (Vesktop)" })
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("kitty --class impasto-btop -e btop"),
        { description = "Applications · Open btop" })

-- · pełny ekran bez wiedzy aplikacji (przeglądarka zachowuje karty). Bind
-- · autora trzeba zdjąć, bo ten z custom/ działa dopiero po nim.
hl.unbind(mainMod .. " + F")
hl.bind(mainMod .. " + F",
        hl.dsp.window.fullscreen_state({ internal = 2, client = 0, action = "toggle" }),
        { description = "Windows · Full screen (app unaware, so browser keeps its tabs)" })

-- · tryb zmiany rozmiaru: SUPER+R, potem strzałki lub h/j/k/l, Esc/Enter wychodzi
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
