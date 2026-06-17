-- Full nvim-colorizer parity: hex (#rgb / #rrggbb), rgb()/rgba(), hsl()/hsla(),
-- and named CSS colors. mini.hipatterns only ships a hex highlighter, so the
-- rest are custom highlighters that resolve each match to a hex value and reuse
-- mini's cached highlight-group computation.

local function clamp_byte(value) return math.max(0, math.min(255, math.floor(value + 0.5))) end

local function hsl_to_hex(h, s, l)
  h = (h % 360) / 360
  s = s / 100
  l = l / 100

  local function hue_to_rgb(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end
    if t < 1 / 6 then return p + (q - p) * 6 * t end
    if t < 1 / 2 then return q end
    if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
    return p
  end

  local r, g, b
  if s == 0 then
    r, g, b = l, l, l
  else
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    r = hue_to_rgb(p, q, h + 1 / 3)
    g = hue_to_rgb(p, q, h)
    b = hue_to_rgb(p, q, h - 1 / 3)
  end

  return string.format('#%02x%02x%02x', clamp_byte(r * 255), clamp_byte(g * 255), clamp_byte(b * 255))
end

-- 148 CSS named colors (CSS Color Module Level 4).
local css_colors = {
  aliceblue = '#f0f8ff',
  antiquewhite = '#faebd7',
  aqua = '#00ffff',
  aquamarine = '#7fffd4',
  azure = '#f0ffff',
  beige = '#f5f5dc',
  bisque = '#ffe4c4',
  black = '#000000',
  blanchedalmond = '#ffebcd',
  blue = '#0000ff',
  blueviolet = '#8a2be2',
  brown = '#a52a2a',
  burlywood = '#deb887',
  cadetblue = '#5f9ea0',
  chartreuse = '#7fff00',
  chocolate = '#d2691e',
  coral = '#ff7f50',
  cornflowerblue = '#6495ed',
  cornsilk = '#fff8dc',
  crimson = '#dc143c',
  cyan = '#00ffff',
  darkblue = '#00008b',
  darkcyan = '#008b8b',
  darkgoldenrod = '#b8860b',
  darkgray = '#a9a9a9',
  darkgreen = '#006400',
  darkgrey = '#a9a9a9',
  darkkhaki = '#bdb76b',
  darkmagenta = '#8b008b',
  darkolivegreen = '#556b2f',
  darkorange = '#ff8c00',
  darkorchid = '#9932cc',
  darkred = '#8b0000',
  darksalmon = '#e9967a',
  darkseagreen = '#8fbc8f',
  darkslateblue = '#483d8b',
  darkslategray = '#2f4f4f',
  darkslategrey = '#2f4f4f',
  darkturquoise = '#00ced1',
  darkviolet = '#9400d3',
  deeppink = '#ff1493',
  deepskyblue = '#00bfff',
  dimgray = '#696969',
  dimgrey = '#696969',
  dodgerblue = '#1e90ff',
  firebrick = '#b22222',
  floralwhite = '#fffaf0',
  forestgreen = '#228b22',
  fuchsia = '#ff00ff',
  gainsboro = '#dcdcdc',
  ghostwhite = '#f8f8ff',
  gold = '#ffd700',
  goldenrod = '#daa520',
  gray = '#808080',
  green = '#008000',
  greenyellow = '#adff2f',
  grey = '#808080',
  honeydew = '#f0fff0',
  hotpink = '#ff69b4',
  indianred = '#cd5c5c',
  indigo = '#4b0082',
  ivory = '#fffff0',
  khaki = '#f0e68c',
  lavender = '#e6e6fa',
  lavenderblush = '#fff0f5',
  lawngreen = '#7cfc00',
  lemonchiffon = '#fffacd',
  lightblue = '#add8e6',
  lightcoral = '#f08080',
  lightcyan = '#e0ffff',
  lightgoldenrodyellow = '#fafad2',
  lightgray = '#d3d3d3',
  lightgreen = '#90ee90',
  lightgrey = '#d3d3d3',
  lightpink = '#ffb6c1',
  lightsalmon = '#ffa07a',
  lightseagreen = '#20b2aa',
  lightskyblue = '#87cefa',
  lightslategray = '#778899',
  lightslategrey = '#778899',
  lightsteelblue = '#b0c4de',
  lightyellow = '#ffffe0',
  lime = '#00ff00',
  limegreen = '#32cd32',
  linen = '#faf0e6',
  magenta = '#ff00ff',
  maroon = '#800000',
  mediumaquamarine = '#66cdaa',
  mediumblue = '#0000cd',
  mediumorchid = '#ba55d3',
  mediumpurple = '#9370db',
  mediumseagreen = '#3cb371',
  mediumslateblue = '#7b68ee',
  mediumspringgreen = '#00fa9a',
  mediumturquoise = '#48d1cc',
  mediumvioletred = '#c71585',
  midnightblue = '#191970',
  mintcream = '#f5fffa',
  mistyrose = '#ffe4e1',
  moccasin = '#ffe4b5',
  navajowhite = '#ffdead',
  navy = '#000080',
  oldlace = '#fdf5e6',
  olive = '#808000',
  olivedrab = '#6b8e23',
  orange = '#ffa500',
  orangered = '#ff4500',
  orchid = '#da70d6',
  palegoldenrod = '#eee8aa',
  palegreen = '#98fb98',
  paleturquoise = '#afeeee',
  palevioletred = '#db7093',
  papayawhip = '#ffefd5',
  peachpuff = '#ffdab9',
  peru = '#cd853f',
  pink = '#ffc0cb',
  plum = '#dda0dd',
  powderblue = '#b0e0e6',
  purple = '#800080',
  rebeccapurple = '#663399',
  red = '#ff0000',
  rosybrown = '#bc8f8f',
  royalblue = '#4169e1',
  saddlebrown = '#8b4513',
  salmon = '#fa8072',
  sandybrown = '#f4a460',
  seagreen = '#2e8b57',
  seashell = '#fff5ee',
  sienna = '#a0522d',
  silver = '#c0c0c0',
  skyblue = '#87ceeb',
  slateblue = '#6a5acd',
  slategray = '#708090',
  slategrey = '#708090',
  snow = '#fffafa',
  springgreen = '#00ff7f',
  steelblue = '#4682b4',
  tan = '#d2b48c',
  teal = '#008080',
  thistle = '#d8bfd8',
  tomato = '#ff6347',
  turquoise = '#40e0d0',
  violet = '#ee82ee',
  wheat = '#f5deb3',
  white = '#ffffff',
  whitesmoke = '#f5f5f5',
  yellow = '#ffff00',
  yellowgreen = '#9acd32',
}

return {
  'echasnovski/mini.hipatterns',
  version = '*',
  lazy = false,
  config = function()
    local hipatterns = require('mini.hipatterns')

    local function rgb_group(_, match)
      local r, g, b = match:match('(%d+)%D+(%d+)%D+(%d+)')
      if not r then return nil end
      local hex = string.format('#%02x%02x%02x', clamp_byte(tonumber(r)), clamp_byte(tonumber(g)), clamp_byte(tonumber(b)))
      return hipatterns.compute_hex_color_group(hex, 'bg')
    end

    local function hsl_group(_, match)
      local h, s, l = match:match('(%d+)%D+(%d+)%D+(%d+)')
      if not h then return nil end
      return hipatterns.compute_hex_color_group(hsl_to_hex(tonumber(h), tonumber(s), tonumber(l)), 'bg')
    end

    local function named_group(_, match)
      local hex = css_colors[match:lower()]
      if not hex then return nil end
      return hipatterns.compute_hex_color_group(hex, 'bg')
    end

    local function short_hex_group(_, match)
      local r, g, b = match:match('#(%x)(%x)(%x)')
      local hex = '#' .. r .. r .. g .. g .. b .. b
      return hipatterns.compute_hex_color_group(hex, 'bg')
    end

    hipatterns.setup({
      highlighters = {
        hex_color = hipatterns.gen_highlighter.hex_color(),
        short_hex_color = { pattern = '#%x%x%x%f[%X]', group = short_hex_group },
        rgb_color = { pattern = 'rgba?%([%d%s,%.%%]+%)', group = rgb_group },
        hsl_color = { pattern = 'hsla?%([%d%s,%.%%]+%)', group = hsl_group },
        css_named = { pattern = '%f[%a][%a][%a][%a]+%f[%A]', group = named_group },
      },
    })
  end,
}
