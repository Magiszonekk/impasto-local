-- Lokalne reguły okien (magiszonek): małe okna kitty z przycisków na pasku.
local function popup(name, class, w, h)
    hl.window_rule({
        name  = name,
        match = { class = "^(" .. class .. ")$" },

        float  = true,
        center = true,
        size   = { w, h },
    })
end

popup("sudo-window",      "impasto-sudo",      560,  240)
popup("btop-window",      "impasto-btop",      1100, 700)
popup("speedtest-window", "impasto-speedtest", 1100, 560)
popup("vpn-window",       "impasto-vpn",       460,  260)
