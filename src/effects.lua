g_effect_id = 0

function effects_init()
  g_state.effects = {}
  g_state.remove_effects = {}
end

function effects_draw()
  for id, effect in pairs(g_state.effects) do
    if effect and effect.sprite then
      draw_sprite(effect.sprite, effect.timer, effect.x, effect.y, 0, effect.sx, effect.sy)
    end
  end
end

function effects_update(dt)
  effects_process_removals()
  for id, effect in pairs(g_state.effects) do
    effect.timer = effect.timer + dt * effect.rate
    if (not effect.sprite) or effect.timer >= effect.animation_end then
      effects_remove(id)
    end
  end
  effects_process_removals()
end

function effects_create(opts)
  local id = g_effect_id
  g_effect_id = g_effect_id + 1

  assert(opts.x and opts.y and opts.sprite)

  local animation_begin, animation_end = unpack(opts.subimage_range or {})
  animation_begin = animation_begin or 0
  animation_end = animation_end or opts.sprite.subimages

  if opts.duration then
    opts.rate = (animation_end - animation_begin) / opts.duration
  elseif opts.interval and opts.interval ~= 0 then
    opts.rate = 1 / opts.interval
  end

  g_state.effects[id] = {
    x = opts.x,
    y = opts.y,
    sprite = opts.sprite,
    rate = opts.rate or 0.2,
    timer = animation_begin,
    animation_end = animation_end,
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