-- Prefix passthrough for terminal applications.
rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- Repeatable pane navigation: Ctrl+B, Ctrl+R enters; Enter/Escape exits.
rex.mode("repeat", { exclusive = true })
rex.bind("ctrl+b>ctrl+r", "client.mode.enter", { name = "repeat" })
rex.bind("repeat/enter", "client.mode.exit")
rex.bind("repeat/escape", "client.mode.exit")

rex.bind("ctrl+b>k", "pane.focus", { direction = "up" })
rex.bind("repeat/k", "pane.focus", { direction = "up" })
rex.bind("ctrl+b>j", "pane.focus", { direction = "down" })
rex.bind("repeat/j", "pane.focus", { direction = "down" })
rex.bind("ctrl+b>h", "pane.focus", { direction = "left" })
rex.bind("repeat/h", "pane.focus", { direction = "left" })
rex.bind("ctrl+b>l", "pane.focus", { direction = "right" })
rex.bind("repeat/l", "pane.focus", { direction = "right" })

rex.bind("ctrl+b>shift+\\", "pane.split", { direction = "right" })
rex.bind("ctrl+b>-", "pane.split", { direction = "down" })
rex.bind("ctrl+b>c", "client.tab.new")
rex.bind("ctrl+b>r", "client.config.reload")
rex.bind("ctrl+b>z", "pane.zoom")
rex.bind("ctrl+b>shift+;", "client.palette.toggle")
