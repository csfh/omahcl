require "zlib"

# Renders the Omarchy Verified card as a 1200x630 PNG for link previews.
# Pure Ruby (stdlib Zlib plus a 5x7 bitmap font) so it needs no gem or system
# image library on Laravel Cloud. It draws a 400x210 pixel grid and scales it 3x,
# which also gives the stepped, blocky look the site uses. The card is drawn flat
# on its own layer, then tilted onto the canvas.
class CardImage
  SCALE = 3
  WIDTH = 400
  HEIGHT = 210

  INK = [ 0x13, 0x1c, 0x1e ].freeze
  PANEL = [ 0x1a, 0x25, 0x27 ].freeze
  PAPER = [ 0xdc, 0xcf, 0xb4 ].freeze
  MUTED = [ 0x9f, 0xa8, 0x9f ].freeze
  ACCENT = [ 0x86, 0xc5, 0xba ].freeze
  TEAL_DEEP = [ 0x35, 0x52, 0x4f ].freeze
  LINE = [ 0x2d, 0x40, 0x42 ].freeze
  WHITE = [ 0xff, 0xff, 0xff ].freeze

  FOIL = [
    [ 0x5f, 0xd1, 0xc0 ], [ 0xb8, 0xf0, 0xe6 ], [ 0x9b, 0x7b, 0xff ],
    [ 0xff, 0x7a, 0xb8 ], [ 0xff, 0xd1, 0x66 ], [ 0x5f, 0xd1, 0xc0 ]
  ].freeze

  CARD_W = 124
  CARD_H = 174
  CARD_CENTER = [ 86, 105 ].freeze
  TILT = -4 * Math::PI / 180
  SHADOW = [ 5, 5 ].freeze

  COLUMN_X = 176
  COLUMN_W = 200

  # 4x4 ordered-dither thresholds, so every gradient stays stepped pixel art.
  BAYER = [ [ 0, 8, 2, 10 ], [ 12, 4, 14, 6 ], [ 3, 11, 1, 9 ], [ 15, 7, 13, 5 ] ].freeze

  # The seal is an octagon on a 12x12 grid. The rim is the outer shape and the fill is
  # every cell of it whose four neighbours are also in it, so the two always line up.
  # The check spans x 3-8, y 4-7: centred, with a two-cell margin to the fill's edge.
  # Its left arm ends lower than its right tip.
  SEAL_SIZE = 12
  OUTER_RECTS = [ [ 4, 0, 4, 12 ], [ 2, 1, 8, 10 ], [ 1, 2, 10, 8 ], [ 0, 3, 12, 6 ] ].freeze
  OUTER = OUTER_RECTS.flat_map { |x, y, w, h| (x...(x + w)).flat_map { |col| (y...(y + h)).map { |row| [ col, row ] } } }.uniq.freeze
  INNER = OUTER.select { |x, y| [ [ 1, 0 ], [ -1, 0 ], [ 0, 1 ], [ 0, -1 ] ].all? { |dx, dy| OUTER.include?([ x + dx, y + dy ]) } }.freeze
  CHECK = [ [ 7, 4 ], [ 8, 4 ], [ 6, 5 ], [ 7, 5 ], [ 3, 6 ], [ 5, 6 ], [ 6, 6 ], [ 4, 7 ], [ 5, 7 ] ].freeze

  def self.cells_path(cells)
    cells.map { |x, y| "M#{x} #{y}h1v1h-1z" }.join
  end

  def initialize(name:, cpu:, gpu:, version:)
    @name = name
    @cpu = cpu
    @gpu = gpu
    @version = version
    @pixels = Array.new(HEIGHT) { Array.new(WIDTH, INK) }
  end

  def png
    background
    card
    copy
    encode
  end

  private

  def fill(x, y, w, h, color, grid = @pixels)
    (y...(y + h)).each do |row|
      next unless row.between?(0, grid.length - 1)

      (x...(x + w)).each { |col| grid[row][col] = color if col.between?(0, grid[row].length - 1) }
    end
  end

  def threshold(x, y)
    (BAYER[y % 4][x % 4] + 0.5) / 16
  end

  def distance(x, y, cx, cy)
    Math.hypot(x - cx, y - cy)
  end

  def seeded(seed)
    seed = (seed * 1103515245 + 12345) & 0x7fffffff
    [ seed, seed ]
  end

  # A dotted pixel grid, a soft dithered glow behind the card, and a few stars.
  def background
    cx, cy = CARD_CENTER

    HEIGHT.times do |y|
      WIDTH.times do |x|
        glow = 1 - distance(x, y, cx, cy) / 150.0
        next unless glow > 0

        strength = glow**1.6 * 0.9
        @pixels[y][x] = mix(INK, TEAL_DEEP, 0.75) if strength > threshold(x, y)
      end
    end

    (6...HEIGHT).step(12) { |y| (6...WIDTH).step(12) { |x| @pixels[y][x] = mix(@pixels[y][x], LINE, 0.8) } }

    seed = Zlib.crc32("stars-#{@name}")
    46.times do
      seed, = seeded(seed)
      x = seed % WIDTH
      seed, = seeded(seed)
      y = seed % HEIGHT
      @pixels[y][x] = mix(@pixels[y][x], PAPER, 0.35)
    end

    fill(0, 0, WIDTH, 2, LINE)
    fill(0, HEIGHT - 2, WIDTH, 2, LINE)
  end

  # Tilts the flat card onto the canvas with a hard offset shadow behind it.
  def card
    layer = card_layer
    cx, cy = CARD_CENTER
    cos = Math.cos(TILT)
    sin = Math.sin(TILT)

    sample = lambda do |x, y|
      dx = x - cx
      dy = y - cy
      lx = (dx * cos + dy * sin + CARD_W / 2.0).floor
      ly = (-dx * sin + dy * cos + CARD_H / 2.0).floor
      lx.between?(0, CARD_W - 1) && ly.between?(0, CARD_H - 1) ? layer[ly][lx] : nil
    end

    area = ((cy - 120)...(cy + 120)).to_a.product(((cx - 120)...(cx + 120)).to_a)
      .select { |y, x| x.between?(0, WIDTH - 1) && y.between?(0, HEIGHT - 1) }

    area.each { |y, x| @pixels[y][x] = TEAL_DEEP if sample.call(x - SHADOW[0], y - SHADOW[1]) }
    area.each do |y, x|
      color = sample.call(x, y)
      @pixels[y][x] = color if color
    end

    seal
  end

  def card_layer
    layer = Array.new(CARD_H) { Array.new(CARD_W) }
    fill(0, 0, CARD_W, CARD_H, ACCENT, layer)
    [ [ 0, 0 ], [ CARD_W - 2, 0 ], [ 0, CARD_H - 2 ], [ CARD_W - 2, CARD_H - 2 ] ].each { |x, y| fill(x, y, 2, 2, nil, layer) }

    (2...(CARD_H - 2)).each do |y|
      (2...(CARD_W - 2)).each { |x| layer[y][x] = foil(x, y) }
    end

    sparkles(layer)
    seal_glow(layer)
    layer
  end

  # Rainbow bands dithered between neighbouring colours, with a diagonal glare.
  def foil(x, y)
    u = x.fdiv(CARD_W)
    v = y.fdiv(CARD_H)
    position = ((u * 0.9 + v * 0.75) * 1.5 % 1.0) * FOIL.length
    base = position.floor
    color = position - base > threshold(x, y) ? FOIL[(base + 1) % FOIL.length] : FOIL[base % FOIL.length]
    color = mix(color, PANEL, 0.26)

    glare = [ 1 - ((u * 0.8 + v * 0.6) - 0.62).abs / 0.2, 0 ].max
    if glare > 0.75 + threshold(x, y) * 0.25
      mix(color, WHITE, 0.5)
    elsif glare > threshold(x, y)
      mix(color, WHITE, 0.25)
    else
      color
    end
  end

  # Four-point stars: a few big ones, many small.
  def sparkles(layer)
    seed = Zlib.crc32(@name)
    16.times do |i|
      seed, = seeded(seed)
      x = 8 + seed % (CARD_W - 16)
      seed, = seeded(seed)
      y = 8 + seed % (CARD_H - 16)
      next if distance(x, y, CARD_W / 2, CARD_H / 2) < 40

      arm = i < 4 ? 3 : 1
      (-arm..arm).each do |d|
        color = d.abs > 1 ? mix(WHITE, ACCENT, 0.5) : WHITE
        fill(x + d, y, 1, 1, color, layer)
        fill(x, y + d, 1, 1, color, layer)
      end
    end
  end

  SEAL_UNIT = 6

  # The glow is part of the tilted card; the seal itself is drawn upright on top.
  def seal_glow(layer)
    radius = SEAL_SIZE * SEAL_UNIT / 2.0
    CARD_H.times do |y|
      CARD_W.times do |x|
        next unless layer[y][x]

        glow = 1 - (distance(x, y, CARD_W / 2, CARD_H / 2) - radius) / 22
        layer[y][x] = mix(layer[y][x], WHITE, 0.4) if glow > 0 && glow > threshold(x, y)
      end
    end
  end

  def seal
    size = SEAL_SIZE * SEAL_UNIT
    ox = CARD_CENTER[0] - size / 2
    oy = CARD_CENTER[1] - size / 2
    [ [ OUTER, TEAL_DEEP ], [ INNER, ACCENT ], [ CHECK, INK ] ].each do |cells, color|
      cells.each { |x, y| fill(ox + x * SEAL_UNIT, oy + y * SEAL_UNIT, SEAL_UNIT, SEAL_UNIT, color) }
    end
  end

  def copy
    left = COLUMN_X
    text("OMARCHY VERIFIED", centered_x("OMARCHY VERIFIED", left, COLUMN_W, 2), 30, ACCENT, scale: 2)
    fill(left, 52, COLUMN_W, 2, TEAL_DEEP)

    y = 68
    wrap(@name, 16, 3).each do |line|
      text(line, left, y, PAPER, scale: 2)
      y += 18
    end

    y = [ y + 10, 126 ].max
    [ [ "CPU", @cpu ], [ "GPU", @gpu ], [ "OMARCHY", @version ] ].each do |label, value|
      text(label, left, y, MUTED)
      text(clip(value, 22), left + 60, y, PAPER)
      y += 14
    end

    text("OMAHCL.COM", centered_x("OMAHCL.COM", left, COLUMN_W, 1), 176, ACCENT)
  end

  def mix(color, other, amount)
    color.zip(other).map { |a, b| (a * (1 - amount) + b * amount).round }
  end

  def normalize(string)
    I18n.transliterate(string.to_s).upcase.gsub(/[^A-Z0-9 .,\-\/+():'&_#]/, "?")
  end

  def clip(value, limit)
    string = normalize(value)
    string.length > limit ? "#{string[0, limit - 2]}.." : string
  end

  def wrap(string, limit, max_lines)
    lines = [ "" ]
    normalize(string).split.each do |word|
      candidate = lines.last.empty? ? word : "#{lines.last} #{word}"
      if candidate.length <= limit
        lines[-1] = candidate
      elsif lines.length < max_lines
        lines << word[0, limit]
      else
        lines[-1] = clip("#{lines.last} #{word}", limit)
        break
      end
    end
    lines.map { |line| clip(line, limit) }
  end

  # The last glyph's trailing gap column is not ink, so leave it out when centring.
  def centered_x(string, left, width, scale)
    left + (width - (string.length * 6 - 1) * scale) / 2
  end

  def text(string, x, y, color, scale: 1)
    normalize(string).each_char.with_index do |char, index|
      glyph = Font::GLYPHS.fetch(char) { Font::GLYPHS.fetch("?") }
      glyph.each_with_index do |bits, row|
        bits.each_char.with_index do |bit, col|
          next unless bit == "1"

          fill(x + index * 6 * scale + col * scale, y + row * scale, scale, scale, color)
        end
      end
    end
  end

  def encode
    packed = Hash.new { |hash, color| hash[color] = color.pack("C3") * SCALE }
    rows = @pixels.flat_map do |row|
      line = "\x00".b + row.map { |color| packed[color] }.join
      [ line ] * SCALE
    end

    chunk = lambda do |type, data|
      [ data.bytesize ].pack("N") + type + data + [ Zlib.crc32(type + data) ].pack("N")
    end
    header = [ WIDTH * SCALE, HEIGHT * SCALE, 8, 2, 0, 0, 0 ].pack("NNCCCCC")

    "\x89PNG\r\n\x1a\n".b +
      chunk.call("IHDR", header) +
      chunk.call("IDAT", Zlib::Deflate.deflate(rows.join, Zlib::BEST_COMPRESSION)) +
      chunk.call("IEND", "")
  end
end
