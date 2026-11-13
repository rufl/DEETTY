-- DINTTY integration for Noctalia on Hyprland's Lua configuration.
hl.on("hyprland.start", function()
  hl.exec_cmd("dintty --hidden")
end)

hl.bind("F10", hl.dsp.exec_cmd("dintty --toggle"))

hl.layer_rule({
  name = "dintty",
  match = { namespace = "^dintty-" },
  no_anim = true,
})
