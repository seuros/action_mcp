# frozen_string_literal: true

# Natural, collision-free MCP Apps demo. "color_palette" isn't a Claude
# built-in, and the description steers the model to render the widget rather
# than inventing colors in text.
class ColorPaletteTool < ApplicationMCPTool
  tool_name "color_palette"
  description "Generate a color palette for a theme and render it as an interactive, " \
              "copyable swatch widget. Use whenever the user wants colors, a palette, " \
              "or a color scheme for a design, brand, mood, or theme."

  renders_ui "ui://views/color-palette"

  property :theme, type: "string", required: true,
                   description: "Mood or theme for the palette, e.g. 'sunset landing page', 'calm ocean', 'neon arcade'"
  property :count, type: "integer", default: 5, description: "Number of swatches (3–8)"

  output_schema do
    property :theme, type: "string", required: true
    # Flat items so the view can read swatch.hex / swatch.name directly.
    array :swatches, items: {
      "type" => "object",
      "properties" => { "hex" => { "type" => "string" }, "name" => { "type" => "string" } },
      "required" => %w[hex name]
    }
  end

  # Keyword → hue window (degrees). First match biases the palette so a natural
  # request lands on fitting colors.
  THEME_HUES = {
    "sunset" => [ 5, 45 ], "sunrise" => [ 30, 55 ], "fire" => [ 0, 30 ], "warm" => [ 10, 45 ],
    "autumn" => [ 15, 45 ], "gold" => [ 40, 52 ], "desert" => [ 30, 50 ],
    "ocean" => [ 185, 220 ], "sea" => [ 185, 220 ], "water" => [ 190, 215 ], "ice" => [ 190, 210 ],
    "sky" => [ 200, 220 ], "cool" => [ 200, 245 ], "arctic" => [ 190, 215 ],
    "forest" => [ 100, 150 ], "nature" => [ 90, 150 ], "jungle" => [ 110, 150 ], "mint" => [ 150, 170 ],
    "lavender" => [ 260, 285 ], "plum" => [ 280, 300 ], "grape" => [ 270, 295 ],
    "berry" => [ 300, 330 ], "rose" => [ 335, 355 ], "pink" => [ 320, 345 ], "candy" => [ 300, 340 ],
    "midnight" => [ 220, 250 ], "night" => [ 225, 255 ], "galaxy" => [ 255, 285 ], "storm" => [ 205, 235 ],
    "coffee" => [ 22, 40 ], "chocolate" => [ 18, 36 ], "earth" => [ 25, 45 ], "wood" => [ 22, 42 ],
    "lemon" => [ 48, 60 ], "royal" => [ 250, 275 ], "blossom" => [ 320, 345 ]
  }.freeze

  # (upper-bound degree, family) — first bucket whose bound the hue is under.
  HUE_NAMES = [
    [ 16, "Red" ], [ 40, "Coral" ], [ 52, "Orange" ], [ 66, "Amber" ], [ 90, "Yellow" ],
    [ 105, "Lime" ], [ 150, "Green" ], [ 175, "Teal" ], [ 200, "Cyan" ], [ 250, "Blue" ],
    [ 280, "Indigo" ], [ 320, "Violet" ], [ 345, "Magenta" ], [ 361, "Red" ]
  ].freeze

  # Literal color words → hue (degrees). When the theme names colors, those
  # hues are pinned instead of being inferred from mood.
  NAMED_HUES = {
    "red" => 0, "crimson" => 350, "scarlet" => 8, "maroon" => 355, "brick" => 6,
    "coral" => 14, "salmon" => 12, "orange" => 30, "tangerine" => 28, "peach" => 26,
    "amber" => 45, "gold" => 48, "yellow" => 55, "lemon" => 58, "chartreuse" => 80,
    "lime" => 90, "green" => 120, "emerald" => 150, "mint" => 160, "teal" => 175,
    "cyan" => 185, "aqua" => 185, "turquoise" => 180, "sky" => 200, "azure" => 210,
    "blue" => 222, "cobalt" => 225, "navy" => 230, "indigo" => 260, "violet" => 272,
    "purple" => 285, "lavender" => 270, "magenta" => 300, "fuchsia" => 310,
    "pink" => 330, "rose" => 345, "plum" => 290
  }.freeze

  ANCHOR_RE = Regexp.union(
    /#(?:[0-9a-f]{6}|[0-9a-f]{3})\b/,
    *NAMED_HUES.keys.map { |w| /\b#{w}\b/ }
  )

  def perform
    n = count.to_i.clamp(3, 8)
    t = theme.to_s.downcase
    anchors = anchor_hues(t)

    hues, tone_mode =
      if anchors.size >= 2
        [ sample_anchor_hues(anchors, n), :flat ]  # honor the named colors as-is
      elsif anchors.size == 1
        [ Array.new(n) { anchors.first }, :ramp ]  # shades of the one named color
      else
        [ spread_hues(t, n), :ramp ]               # infer from mood
      end

    swatches = hues.each_with_index.map do |hue, i|
      f = n == 1 ? 0.5 : i.to_f / (n - 1)
      s, l = swatch_tone(t, f, tone_mode)
      h = hue.round % 360
      { hex: hsl_to_hex(h, s, l), name: color_name(h, l) }
    end

    render text: "Palette for #{theme.inspect}: #{swatches.map { |x| x[:hex] }.join(' ')}"
    render structured: { theme: theme, swatches: swatches }
  end

  private

  # Hues named literally in the theme (color words + hex codes), in order of
  # appearance. Empty when the theme only describes a mood.
  def anchor_hues(theme)
    theme.scan(ANCHOR_RE).map { |tok| tok.start_with?("#") ? hex_to_hue(tok) : NAMED_HUES[tok] }.compact
  end

  # Spread `n` hues along the anchor sequence (interpolating between named
  # colors so red→yellow→green flows smoothly for extra swatches).
  def sample_anchor_hues(anchors, n)
    k = anchors.size
    return anchors.first(n) if k >= n

    Array.new(n) do |j|
      pos = j.to_f / (n - 1) * (k - 1)
      lo = pos.floor
      hi = [ lo + 1, k - 1 ].min
      lerp_hue(anchors[lo], anchors[hi], pos - lo)
    end
  end

  # Mood-inferred hues fanned around a base (previous default behaviour).
  def spread_hues(theme, n)
    base = base_hue(theme)
    spread = hue_spread(theme)
    Array.new(n) { |i| base + ((n == 1 ? 0.5 : i.to_f / (n - 1)) - 0.5) * 2 * spread }
  end

  # Center hue: the first matching theme keyword, else deterministic from text.
  def base_hue(theme)
    THEME_HUES.each { |kw, (lo, hi)| return ((lo + hi) / 2) % 360 if theme.include?(kw) }
    crc(theme) % 360
  end

  # Shortest-arc interpolation between two hues.
  def lerp_hue(a, b, t)
    delta = ((b - a + 540) % 360) - 180
    (a + delta * t) % 360
  end

  # Per-swatch saturation/lightness. Flat mode keeps named colors reading true;
  # ramp mode fades light → deep across the row.
  def swatch_tone(theme, fraction, mode)
    sat_lo, sat_hi, lig_lo, lig_hi = tone(theme)
    if mode == :flat
      s = (sat_lo + sat_hi) / 2
      lmid = (lig_lo + lig_hi) / 2
      l = (lmid + (fraction - 0.5) * 12).round.clamp(20, 90)
      [ s, l ]
    else
      s = (sat_lo + (sat_hi - sat_lo) * fraction).round
      l = (lig_hi - (lig_hi - lig_lo) * fraction).round
      [ s, l ]
    end
  end

  # "#rgb" / "#rrggbb" → hue degrees.
  def hex_to_hue(hex)
    h = hex.delete("#")
    h = h.chars.map { |c| c * 2 }.join if h.size == 3
    rgb_to_hue(h[0, 2].to_i(16), h[2, 2].to_i(16), h[4, 2].to_i(16))
  end

  def rgb_to_hue(r, g, b)
    r /= 255.0
    g /= 255.0
    b /= 255.0
    max = [ r, g, b ].max
    delta = max - [ r, g, b ].min
    return 0 if delta.zero?

    h =
      case max
      when r then ((g - b) / delta) % 6
      when g then (b - r) / delta + 2
      else        (r - g) / delta + 4
      end
    (h * 60).round % 360
  end

  # How far around the wheel the swatches spread. Vibrant themes fan out into a
  # multi-color set; calm/mono themes stay tight around the base hue.
  def hue_spread(theme)
    return 120 if theme.match?(/neon|arcade|rainbow|vivid|party|pride|disco|festive|candy|retro/)
    return 18  if theme.match?(/mono|minimal|single|calm|zen/)

    45
  end

  def tone(theme)
    return [ 40, 55, 78, 90 ] if theme.match?(/pastel|soft|calm|gentle/)
    return [ 92, 100, 55, 66 ] if theme.match?(/neon|vivid|electric|arcade|cyber/)
    return [ 30, 55, 28, 48 ] if theme.match?(/dark|midnight|night|noir|deep/)
    return [ 20, 40, 45, 68 ] if theme.match?(/muted|earthy|vintage|dusty/)

    [ 62, 78, 48, 70 ]
  end

  def color_name(hue, lightness)
    family = HUE_NAMES.find { |bound, _| hue < bound }.last
    qualifier =
      if lightness < 35 then "Deep "
      elsif lightness >= 72 then "Pale "
      elsif lightness >= 60 then "Soft "
      else ""
      end
    "#{qualifier}#{family}"
  end

  def crc(str)
    require "zlib"
    Zlib.crc32(str)
  end

  # HSL (h 0–360, s/l 0–100) → #RRGGBB
  def hsl_to_hex(h, s, l)
    h %= 360
    s /= 100.0
    l /= 100.0
    c = (1 - (2 * l - 1).abs) * s
    x = c * (1 - ((h / 60.0) % 2 - 1).abs)
    m = l - c / 2
    r, g, b =
      case h
      when 0...60    then [ c, x, 0 ]
      when 60...120  then [ x, c, 0 ]
      when 120...180 then [ 0, c, x ]
      when 180...240 then [ 0, x, c ]
      when 240...300 then [ x, 0, c ]
      else                [ c, 0, x ]
      end
    format("#%02X%02X%02X", ((r + m) * 255).round, ((g + m) * 255).round, ((b + m) * 255).round)
  end
end
