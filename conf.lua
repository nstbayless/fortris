function love.conf(t)
  t.version = "11.3"
  t.identity = "Fortris"
  t.console = false

  if t.window then
    t.window.title = t.identity
    t.window.width = 1424
    t.window.height = 968
    t.window.resizable = true
  else
    t.width = 1024
    t.height = 900
  end
  if t.modules then
    t.modules.physics = false
  end
end
