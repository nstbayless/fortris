local s = require("src.bgfx.bgfx_util")
local s, sr, set_s_array = s.s, s.sr, s.set_s_array

-- rock image indices
-- ordered first by x (left, middle, right) then by y (top, centre, bottom), but skipping (middle, centre).
K_TREE_IDX = { }

-- generate table...
do
  set_s_array(K_TREE_IDX)

  -- default (centres are all active)
  for i = 0,0x600 do
    if bit.band(i, 0x10) == 0x10 then
      local v = bit.rshift(bit.band(i, 0x600), 9)
      K_TREE_IDX[i] = 8*6 + 3 + v
    end
  end

  local i = false
  for v = 0, 2 do
    local v2 = 2 * v
    -- middle ----------------------
    s(1 + v,
      1, 1, 1,
      1, 1, 1,
      1, 1, 1, v)

    -- outer corners ---------------
    sr(30 + v2, 31 + v2, 37 + v2, 36 + v2,
      i, 0, i,
      0, 1, 1,
      i, 1, 1, v)

    -- edges -----------------------
    sr(24 + v2, 18 + v2, 19 + v2, 25 + v2,
      i, 0, i,
      1, 1, 1,
      1, 1, 1, v)

    -- inner corners --------------
    sr(6 + v2, 7 + v2, 13 + v2, 12 + v2,
      1, 1, 1,
      1, 1, 1,
      1, 1, 0, v)

    -- double corners -------------
    s(7 * 6 + 2 + (v % 2),
      1, 1, 0,
      1, 1, 1,
      0, 1, 1, v)
    s(7 * 6 + v % 2,
      0, 1, 1,
      1, 1, 1,
      1, 1, 0, v)

    ------------------------------- [full-thin connectors]
    -- we don't have these sprites, so we ignore them.

    -- edge-inner (chiral A) -----
    sr(30 + 4, 31 + 4, 37 + 4, 36 + 4,
    i, 1, 0,
    0, 1, 1,
    i, 1, 1, v)

    -- edge-inner (chiral B) -----
    sr(30 + 4, 31 + 4, 37 + 4, 36 + 4,
      i, 0, i,
      1, 1, 1,
      0, 1, 1, v)

    -- T-double corners -----------
    sr(24 + 4, 18 + 4, 19 + 4, 25 + 4,
      0, 1, 0,
      1, 1, 1,
      1, 1, 1, v)

    -- K-intersections ------------
    sr(30 + 4, 31 + 4, 37 + 4, 36 + 4,
      0, 1, 0,
      1, 1, 1,
      0, 1, 1, v)
  end
end