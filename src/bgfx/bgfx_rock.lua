-- rock image indices
-- ordered first by x (left, middle, right) then by y (top, centre, bottom), but skipping (middle, centre).
local K_ROCK_IDX = { }

-- generate table...
do
  local function rindex(tl, t, tr, l, c, r, bl, b, br, v)
    return tl + 2 * t + 4 * tr + 8 * l + 0x10 * c + 0x20 * r + 0x40 * bl + 0x80 * b + 0x100 * br + 0x200 * v
  end

  local function s(value, ...)
    local a = {...}
    assert(#a == 10)
    for i, v in ipairs(a) do
      if v == false then
        a[i] = 0
        s(value, unpack(a))
        a[i] = 1
        s(value, unpack(a))
        return
      end
    end
    K_ROCK_IDX[rindex(...)] = value
  end

  local function sr(a0, a1, a2, a3, tl, t, tr, l, c, r, bl, b, br, v)
    local a = {a0, a1, a2, a3}
    for i = 1,4 do
      s(a[i], tl, t, tr, l, c, r, bl, b, br, v)

      -- rotate
      tl, t, tr, r, br, b, bl, l = bl, l, tl, t, tr, r, br, b
    end
  end

  -- default (centres are all active)
  for i = 0,0x400 do
    if bit.band(i, 0x10) == 0x10 then
      K_ROCK_IDX[i] = 0x15
    end
  end

  local i = false
  for v = 0, 1 do
    local v3 = 3 * v
    -- middle ----------------------
    s(0x12 + v3,
      1, 1, 1,
      1, 1, 1,
      1, 1, 1, v)

    -- outer corners ---------------
    sr(0x01 + v3, 0x03 + v3, 0x23 + v3, 0x21 + v3,
      i, 0, i,
      0, 1, 1,
      i, 1, 1, v)

    -- edges -----------------------
    sr(0x02 + v3, 0x13 + v3, 0x22 + v3, 0x11 + v3,
      i, 0, i,
      1, 1, 1,
      1, 1, 1, v)

    -- inner corners --------------
    sr(0x0a, 0x0b, 0x1b, 0x1a,
      0, 1, 1,
      1, 1, 1,
      1, 1, 1, v)

    -- edge-inner (chiral A) -----
    sr(0x2a, 0x2d, 0x3b, 0x3c,
      i, 0, i,
      1, 1, 1,
      1, 1, 0, v)

    -- edge-inner (chiral B) -----
    sr(0x2b, 0x3d, 0x3a, 0x2c,
      i, 0, i,
      1, 1, 1,
      0, 1, 1, v)

    -- double corners -------------
    s(0x0e + v,
      1, 1, 0,
      1, 1, 1,
      0, 1, 1, v)
    s(0x1e + v,
      0, 1, 1,
      1, 1, 1,
      1, 1, 0, v)

    -- T-double corners -----------
    sr(0x55, 0x45, 0x46, 0x56,
      1, 1, 1,
      1, 1, 1,
      0, 1, 0, v)

    -- K-intersections ------------
    sr(0x2f, 0x3f, 0x2e, 0x3e,
      1, 1, 0,
      1, 1, 1,
      0, 1, 0, v)
    
    -- lines ----------------------
    s(0x40,
      i, 1, i,
      0, 1, 0,
      i, 1, i, v)
    s(0x32,
      i, 0, i,
      1, 1, 1,
      i, 0, i, v)
    
    -- line caps ------------------
    sr(0x30, 0x33, 0x50, 0x31,
      i, 0, i,
      0, 1, 0,
      i, 1, i, v)

    -- T-intersections ------------
    sr(0x52, 0x41, 0x51, 0x42,
      i, 0, i,
      1, 1, 1,
      0, 1, 0, v)

    -- L-turns --------------------
      sr(0x53, 0x43, 0x44, 0x54,
      i, 0, i,
      0, 1, 1,
      i, 1, 0, v)

    -- +-intersection -------------
    s(0x34,
      0, 1, 0,
      1, 1, 1,
      0, 1, 0, v)
  end
end


-- returns one of four corner tiles for the wall at the given idx
function rock_get_subtile(base_x, base_y, mask, edges_are_rocks)
  local c = 0 -- "context" a bitfield of all the surrounding tiles.

  -- centre
  if bit.band(d(board_get_value(base_x, base_y), 0), mask) == 0 then
    return nil
  end

  -- check 3x3 square to see what rocks are there.
  local idx = 0
  for y= -1,1 do
    for x = -1,1 do
      local i = bit.lshift(1, idx)
      idx = idx + 1
      local masked_tile = bit.band(d(board_get_value(base_x + x, base_y + y, edges_are_rocks and mask or 0), 0), mask)
      if masked_tile ~= 0 then
        c = bit.bor(c, i)
      end
    end
  end

  -- variant
  if bit.band(d(board_get_value(base_x, base_y), 0), K_VARIANT) ~= 0 then
    --c = bit.bor(c, bit.lshift(1, idx))
  end

  return K_ROCK_IDX[c]
end
