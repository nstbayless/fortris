-- allow debugging
if arg[#arg] == "vsc_debug" then require("lldebugger").start() end

k_dim_x = 32
k_dim_y = 32

k_block_colors = {"blue", "darkgray", "gray", "green", "lightblue", "orange", "yellow", "pink", "purple", "red", "red2", "white"}

g_state = {
}
g_images = {}

require("src.util")
require("src.input")
require("src.pathfinding")
require("src.board")
require("src.static")
require("src.sovereignty")
require("src.placement")
require("src.camera")
require("src.sprite")
require("src.unit")

function init_state()
  g_state = {
    time = 0,
  }
  pf_init()
  board_init()
  static_init()
  svy_init()
  init_placement()
  camera_init()
end

function love.load()
  love.graphics.setDefaultFilter("linear", "nearest")
  g_images.grass = love.graphics.newImage("resources/images/non-commercial/checkered-grass.png")
  g_images.castle = love.graphics.newImage("resources/images/oga/wyrmsun-cc0/town_hall.png")
  g_images.goblin = new_sprite("resources/images/oga/wyrmsun-cc-by-sa/goblin_spearman.png", 72, 72, 72/2, 72/2 + 5)
  g_images.blocks = {}
  for i, color in ipairs(k_block_colors) do
    g_images.blocks[color] = love.graphics.newImage("resources/images/oga/kdd-blocks/" .. color .. ".png")
    g_images.blocks[i] = g_images.blocks[color]
  end
  love.graphics.setNewFont(12)

  init_state()
end

function draw_background_layer()
  local w = g_images.grass:getWidth()
  local h = g_images.grass:getHeight()

  -- number of squares in image
  local rep_x = 4
  local rep_y = 4

  local scale_x = k_dim_x / (w / rep_x)
  local scale_y = k_dim_y / (h / rep_y)

  for x = g_state.board.left*k_dim_x,g_state.board.right*k_dim_x - 1,scale_x * w do
    for y = g_state.board.top*k_dim_y,g_state.board.bottom*k_dim_y - 1,scale_y * h do
      love.graphics.draw(g_images.grass, x, y, 0, scale_x, scale_y)
    end
  end
end

function draw_image_on_grid(image, gx, gy, gw, gh)
  if not image then
    return
  end
  gw = gw or 1
  gh = gh or 1
  local w = image:getWidth()
  local h = image:getHeight()
  local sx = gw * k_dim_x / w
  local sy = gh * k_dim_y / h

  love.graphics.draw(image, gx * k_dim_x, gy * k_dim_y, 0, sx, sy)
end

function love.draw()
  love.graphics.setColor(0xff,0xff,0xff)
  love.graphics.setBackgroundColor(0,0,0)
  love.graphics.push()
  camera_apply_transform()
  do
    draw_background_layer()
    board_draw()
    static_draw_all()
    draw_unit_sprite(g_images.goblin, "idle", 0, 1, 1, 4.5 * k_dim_x, 5.5 * k_dim_y, 2, 2)
    draw_placement()
  end
  love.graphics.pop()
end

function love.update(dt)
  g_state.time = g_state.time + dt
  update_input()
  dx = ibool(key_pressed("right")) - ibool(key_pressed("left"))
  dy = ibool(key_pressed("down")) - ibool(key_pressed("up"))
  dr = ibool(key_pressed("s")) - ibool(key_pressed("a"))
  update_placement(dx, dy, dr)
  camera_update()
end