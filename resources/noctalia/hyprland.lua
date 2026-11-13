-- DEETTY integration for Noctalia on Hyprland's Lua configuration.
hl.on("hyprland.start", function()
  hl.exec_cmd("deetty --hidden")
end)

hl.bind("F10", hl.dsp.exec_cmd("deetty --toggle"))

hl.layer_rule({
  name = "deetty",
  match = { namespace = "^deetty-" },
  no_anim = true,
})
