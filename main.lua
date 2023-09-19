-- allow debugging
if arg and arg[#arg] == "vsc_debug" then require("lldebugger").start() end

-- operating system
g_os = love.system.getOS()

-- paranoia / future-proofing against love.js changes...
g_is_web = g_os:lower() == "web" or g_os:lower() == "browser" or g_os:lower() == "firefox" or g_os:lower() == "chrome" or g_os:lower() == "emscripten"

if g_is_web then
  -- JavaScript ffi
  require("ext.js")
end

-- supply missing library if needed
if not bit then
  bit = require("bitop.funcs")
  assert(bit.band and bit.bnot and bit.bor)
end

-- constants
k_dim_x = 32
k_dim_y = 32
k_version = "Fortris v0.8.1"
k_shaders_supported = true
k_tile_canvas = true
K_GAME_OVER_STOP_TIME = 3 -- how long it takes to fade out and stop after game over
K_WARN_STRIPE_SPEED = 7
K_WARNING_BLINK_INTERVAL = 2

k_block_colors = {"blue", "darkgray", "gray", "green", "lightblue", "orange", "yellow", "pink", "purple", "red", "red2", "white"}

g_state = {}
g_images = {}
g_shaders = {}

-- config
g_hold_repeat_input = true
k_hold_repeat_input_initial = 0.28
k_hold_repeat_input_repeat = 0.05
g_show_existing_turrets_when_placing = false

require("src.util")
require("src.clargs")
require("src.filesystem")
require("src.demo")
require("src.misc")
require("src.input")
require("src.pathfinding")
require("src.board")
require("src.static")
require("src.turret")
require("src.flood")
require("src.sovereignty")
require("src.effects")
require("src.placement")
require("src.camera")
require("src.sprite")
require("src.unit")
require("src.bgfx")
require("src.test")

function init_state()
  -- demo and rng can affect everything, so they are init'd first.
  if g_load_demo then
    local contents, size = love.filesystem.read(g_load_demo)
    assert(contents, "error loading demo file " .. g_load_demo) 
    print("demo file loaded, " .. tostring(size) .. " bytes")
    demo_init(contents)
  else
    demo_init()
  end
  rng_init()

  -- essentially the whole game state is stored in this table,
  -- not including certain caches and fully-encapsulated (and re-initializable) module state
  -- and certain configuration values.
  g_state = {
    time = 0,
    spawn_rate = 1/5,
    spawn_progress = 0.5,
    heal_timer = 0,
    heal_rate = 1/21,
    ogre_spawn_rate = 1/80,
    ogre_spawn_progress = tern(g_debug_mode, 1, -1),
    spawn_timer = 0,
    full_feature_timer = 0,
    full_feature = false,
    game_over = false,
    game_over_timer = 0,
    game_over_complete = false,
    initial_board_width = 40,
    initial_board_height = 24,
    kills = 0,
    paused = false,
  }
  g_state.spawnx = math.random(6, g_state.initial_board_width - 7)
  g_state.spawny = math.random(6, g_state.initial_board_height - 7)
  g_state.spiel_y = g_state.spawny
  g_state.spiel_shift_dir = tern(g_state.spawnx <= 16, 1, -1)
  g_state.spiel_x = g_state.spawnx + g_state.spiel_shift_dir * 11
  g_state.sourcex = nil -- can be filled in later by generator.
  g_state.sourcey = nil -- can be filled in later by generator.
  input_init()
  pf_init()
  board_init()
  static_init()
  unit_init()
  svy_init()
  bgfx_init()
  effects_init()
  init_placement()
  camera_init()
  if g_test_mode then
    test_init()
  end
end

function rng_init()
  if demo_is_playback() then
    g_seed = demo_getv("seed")
    print("seed: " .. HX(g_seed, 8) .. " (set by demo)")
  else
    if g_seed == nil then
      g_seed = math.floor(math.abs(os.time()))
      print("seed: " .. HX(g_seed, 8))
    else
      print("seed: " .. HX(g_seed, 8) .. " (set by user)")
    end

    demo_setv("seed", g_seed)
  end

  math.randomseed(g_seed)
  -- gain some randomness by throwing out some random numbers.
  for i = 1,100 + math.random(100) do
    math.random()
  end
end

function love.load()
  math.randomseed(0)
  
  g_shaders.game_over = k_shaders_supported and love.graphics.newShader("resources/shaders/game_over.shader")

  love.graphics.setDefaultFilter("linear", "nearest")
  g_font = love.graphics.newFont("resources/fonts/ofl/autobahn/autobahn.ttf", 27, "normal", dpi())
  g_font_msg = love.graphics.newFont("resources/fonts/ofl/Gamaliel/Gamaliel.otf", 20, "normal", dpi())
  g_font_effect = love.graphics.newFont("resources/fonts/ofl/triod-postnaja/TriodPostnaja.ttf", 15, "normal", dpi())
  g_images.grass = love.graphics.newImage("resources/images/f/checkered-grass.png")
  g_images.castle = love.graphics.newImage("resources/images/pd/wyrmsun-cc0/town_hall.png")
  g_images.goblin = new_sprite("resources/images/cl/wyrmsun-gpl/goblin_spearman.png", 72, 72, 72/2, 72/2 + 5)
  g_images.ogre = new_sprite("resources/images/cl/wyrmsun-gpl/ettin.png", 72*2, 72*2, 72, 80)
  g_images.turret = new_sprite("resources/images/pd/hv/Turret.png", 60, 60, 29, 35)
  g_images.artillery = new_sprite("resources/images/pd/hv/Artillery.png", 80, 80, 40, 60)
  g_images.turret_base = new_sprite("resources/images/pd/hv/Turret-base.png", 60, 40, 21, 15)
  g_images.turret_base_3x3 = new_sprite("resources/images/pd/hv/Turret-base-3x3.png", 48, 48, 24, 24)
  g_images.blood = new_sprite("resources/images/pd/hv/blood.png", 20, 20, 10, 10)
  g_images.muzzle = new_sprite("resources/images/pd/hv/Muzzle.png", 20, 20, 10, 15)
  g_images.wall = new_sprite("resources/images/pd/wyrmsun-cc0/goblin_wall.png", 16, 16)
  g_images.rock = new_sprite("resources/images/pd/wyrmsun-cc0/rock.png", 32, 32)
  g_images.tree = new_sprite("resources/images/pd/wyrmsun-cc0/tree.png", 32, 32)
  g_images.border = new_sprite("resources/images/f/border.png", 16, 16)
  g_images.warnborder = new_sprite("resources/images/f/warnborder.png", 16, 16)
  g_images.warning = love.graphics.newImage("resources/images/f/warning.png")
  g_images.warnstripes = new_sprite("resources/images/f/warnstripes.png", 16, 16)
  g_images.fog_of_war = new_sprite("resources/images/f/fog_of_war.png", 16, 16)
  g_images.blocks = {}
  for i, color in ipairs(k_block_colors) do
    g_images.blocks[color] = love.graphics.newImage("resources/images/pd/kdd-blocks/" .. color .. ".png")
    g_images.blocks[i] = g_images.blocks[color]
  end

  init_state()
end

function draw_background_layer()
  local w = g_images.grass:getWidth()
  local h = g_images.grass:getHeight()

  -- number of squares in image
  local rep_x = 8
  local rep_y = 8

  local scale_x = k_dim_x / (w / rep_x)
  local scale_y = k_dim_y / (h / rep_y)

  -- poor tiling logic
  -- TODO: update / fix this.
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

  love.graphics.draw(image, gx * k_dim_x, gy * k_dim_y, 0, sx, sy);
end

function love.draw()
  love.graphics.setColor(1, 1, 1)
  love.graphics.setBackgroundColor(0,0,0)
  love.graphics.push()
  camera_apply_transform()

  -- global shader
  if k_shaders_supported then
    if g_state.game_over or g_state.paused then
      if g_state.paused then
        g_shaders.game_over:send("weight", 1)  
      else
        g_shaders.game_over:send("weight", math.clamp(g_state.game_over_timer / 2 - 0.5, 0, 0.9))
      end
      love.graphics.setShader(g_shaders.game_over)
    else
      love.graphics.setShader()
    end
  end

  -- draw these in world coordinates, (transformed by camera).
  do
    draw_background_layer()
    bgfx_draw()
    bgfx_draw(BGFX_LAYER.border)
    static_draw_all()
    unit_draw_all()
    if g_debug_mode then
      -- draw semitransparent fog
      love.graphics.setColor(1, 1, 1, 0.5)
      bgfx_draw(BGFX_LAYER.fog)
      love.graphics.setColor(1, 1, 1, 1)
    else
      bgfx_draw(BGFX_LAYER.fog)
    end
    effects_draw()
    svy_board_overlay_draw()
    board_draw_letterbox()
    if not g_state.game_over then
      draw_placement()
    end
    -- TODO: lutro (crash)
    svy_draw_spiel()
  end
  love.graphics.pop()

  -- not affected by camera
  svy_draw_hud()
end

function spawn_monsters(dt)
  -- spawning monsters
  if g_state.placement_count > 2 then
    g_state.spawn_timer = g_state.spawn_timer + dt
    g_state.spawn_rate = g_state.spawn_rate + dt / 500
    g_state.spawn_progress = g_state.spawn_progress + dt * g_state.spawn_rate
    g_state.ogre_spawn_progress = g_state.ogre_spawn_progress + dt * g_state.ogre_spawn_rate

    -- spawn ogre
    if g_state.ogre_spawn_progress >= 1 then
      g_state.ogre_spawn_progress = 0
      g_state.ogre_spawn_rate = math.min(1/15, g_state.ogre_spawn_rate * 1.041)
      local sx, sy = board_perimeter_location(math.random(board_perimeter()))
      unit_emplace(g_images.ogre, sx, sy, {
        move_speed = 0.45 + math.frandom(0.05),
        animation_speed = 2.5,
        healthbar_offy = -40,
        healthbar_width = 50,
        impathable = 0, -- paths through solids
        breaker = true, -- breaks terrain
        squashable = false,
        hp = 30 + g_state.spawn_timer / 22 + math.sqrt(g_state.spawn_timer / 100) + math.frandom(5) + (math.frandom(4) - math.frandom(1)) * (1 + g_state.spawn_timer / 200),
        bounty = math.round(20 - math.clamp(g_state.spawn_timer / 60 - 200, 0, 5)),
      })
    end

    -- spawn goblin
    while g_state.spawn_progress >= 1 do
      g_state.spawn_progress = g_state.spawn_progress - 1
      for _ = 1,30 do
        local sx, sy = board_perimeter_location(math.random(board_perimeter()))
        if svy_pathfind_to_goal(sx, sy) then
          unit_emplace(g_images.goblin, sx, sy, {
            hp = tern(g_state.spawn_timer < 30, 1, 0.5 + g_state.spawn_timer / 30)
          })
          break
        end
      end
    end
  end
end

function love.update(dt)

  -- round dt to power of 2 of a second
  -- this ensures it has a simple representation as a floating point number.
  -- (prevents certain classes of bugs)
  -- TODO: round randomly by frac, but without alerting demo...
  dt = math.round(dt * 4096) / 4096

  if dt == 0 then
    return
  end

  demo_advance()
  demo_setv("dt", dt)
  if demo_is_playback() then
    dt = demo_getv("dt")
    assert(dt)
  end

  -- cap if extreme lag
  dt = math.min(dt, 0.37)

  if g_state.game_over then
    g_state.game_over_timer = g_state.game_over_timer + dt

    if g_state.game_over_timer >= 1.5 and (key_pressed("place")) then
      -- restart game
      init_state()
    else
      -- gradually slow down to a stop.
      dt = dt * math.clamp(1 - g_state.game_over_timer / K_GAME_OVER_STOP_TIME, 0, 1)

      if dt == 0 then
        g_state.game_over_complete = true
      end
    end
  end

  if not g_state.paused then
    g_state.time = g_state.time + dt

    -- full feature timer
    if g_state.placement_count > 4 then
      g_state.full_feature_timer = g_state.full_feature_timer + dt
      g_state.full_feature = true
    end

    -- healing
    if g_state.svy.hp < g_state.svy.hpmax then
      g_state.heal_timer = g_state.heal_timer + dt * g_state.heal_rate
      if g_state.heal_timer > 1 then
        g_state.heal_timer = g_state.heal_timer - 1
        g_state.svy.hp = g_state.svy.hp + 1
      end
    else
      g_state.svy.heal_timer = 0
    end
  end

  if g_test_mode then
    test_update(dt)
  end
  update_input(dt)

  if key_pressed("pause") then
    g_state.paused = not g_state.paused
    if g_state.game_over then
      g_state.paused = false
    end
  end

  if dt > 0 and not g_state.paused then
    svy_update(dt)
    update_placement(dt)
    board_rubble_decay(dt)

    spawn_monsters(dt)
    effects_update(dt)
    static_update_all(dt)
    unit_update_all(dt)
  end
  camera_update(dt)

  if demo_is_recording() and key_pressed("save_demo") then
    demo_save()
  end
end