g_effect_id = 0

function effects_init()
  g_state.effects = {}
  g_state.remove_effects = {}
end

function effects_draw()
  for id, effect in pairs(g_state.effects) do
    if effect and effect.sprite then
      draw_sprite(effect.sprite, effect.timer, effect.x, effect.y, 0, effect.sx, effect.sy)
    elseif effect and effect.text then
      love.graphics.setColor(1, 1, 1, math.clamp((effect.animation_end - effect.timer) / math.max(effect.rate, 1), 0, 1))
      love.graphics.print(effect.text, g_font_effect, effect.x - 10 * #effect.text, effect.y - 6)
      love.graphics.setColor(1, 1, 1)
    end
  end
end

function effects_update(dt)
  effects_process_removals()
  for id, effect in pairs(g_state.effects) do
    effect.timer = effect.timer + dt * effect.rate
    effect.x =  effect.x + dt * effect.xspeed
    effect.y =  effect.y + dt * effect.yspeed
    if (not effect.sprite and not effect.text) or effect.timer >= effect.animation_end then
      effects_remove(id)
    end
  end
  effects_process_removals()
end

function effects_create(opts)
  local id = g_effect_id
  g_effect_id = g_effect_id + 1

  assert(opts.x and opts.y)
  assert(opts.sprite or opts.text)

  local animation_begin, animation_end = unpack(opts.subimage_range or {})
  if opts.sprite then
    animation_begin = animation_begin or 0
    animation_end = animation_end or opts.sprite.subimages

    if opts.duration then
      opts.rate = (animation_end - animation_begin) / opts.duration
    elseif opts.interval and opts.interval ~= 0 then
      opts.rate = 1 / opts.interval
    end
  end

  g_state.effects[id] = {
    x = opts.x,
    y = opts.y,
    xspeed = opts.xspeed or 0,
    yspeed = opts.yspeed or 0,
    text = opts.text,
    sprite = opts.sprite,
    rate = opts.rate or 0.2,
    timer = animation_begin or 0,
    animation_end = animation_end or opts.duration or 1,
    sx = opts.sx or opts.scale_x or opts.scale or 1,
    sy = opts.sy or opts.scale_y or opts.scale or 1,
  }

  return id
end

function effects_remove(id)
  table.insert(g_state.remove_effects, id)
end

function effects_process_removals()
  for id in entries(g_state.remove_effects) do
    g_state.effects[id] = nil
  end
  g_state.remove_effects = {}
end

function effects_create_text(x, y, text)
  effects_create({
    x = x,
    y = y,
    text = text,
    yspeed = -8
  })
end