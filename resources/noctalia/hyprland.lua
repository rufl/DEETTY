-- NOCTTY integration for Noctalia on Hyprland's Lua configuration.
hl.on("hyprland.start", function()
  hl.exec_cmd("noctty --hidden")
end)

hl.bind("F10", hl.dsp.exec_cmd("noctty --toggle"))

hl.layer_rule({
  name = "noctty",
  match = { namespace = "^noctty-" },
  no_anim = true,
})
