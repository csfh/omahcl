require "zlib"

# Renders the Omarchy Verified card as a 1200x630 PNG for link previews.
# Pure Ruby (stdlib Zlib plus a 5x7 bitmap font) so it needs no gem or system
# image library on Laravel Cloud. It draws a 400x210 pixel grid and scales it 3x,
# which also gives the stepped, blocky look the site uses.
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

  FOIL = [
    [ 0x86, 0xc5, 0xba ], [ 0xd3, 0xe8, 0xe4 ], [ 0xc9, 0xa7, 0xff ],
    [ 0xff, 0xb3, 0xd1 ], [ 0xff, 0xe9, 0xa6 ], [ 0x86, 0xc5, 0xba ]
  ].freeze

  CARD = { x: 24, y: 27, w: 112, h: 156 }.freeze

  def initialize(name:, cpu:, gpu:, version:, machines:)
    @name = name
    @cpu = cpu
    @gpu = gpu
    @version = version
    @machines = machines
    @pixels = Array.new(HEIGHT) { Array.new(WIDTH, INK) }
  end

  def png
    background
    card
    seal
    copy
    encode
  end

  private

  def fill(x, y, w, h, color)
    (y...(y + h)).each do |row|
      next unless row.between?(0, HEIGHT - 1)

      (x...(x + w)).each { |col| @pixels[row][col] = color if col.between?(0, WIDTH - 1) }
    end
  end

  def background
    fill(0, 0, WIDTH, HEIGHT, INK)
    fill(0, 0, WIDTH, 2, LINE)
    fill(0, HEIGHT - 2, WIDTH, 2, LINE)
  end

  # Stepped diagonal foil bands, darkened so text stays readable, with a few
  # sparkle pixels placed from the model name so each card differs.
  def card
    x0, y0, w, h = CARD.values_at(:x, :y, :w, :h)
    fill(x0 + 4, y0 + 4, w, h, TEAL_DEEP)
    fill(x0, y0, w, h, ACCENT)
    (2...(h - 2)).each do |row|
      (2...(w - 2)).each do |col|
        band = ((col.fdiv(w) * 0.9 + row.fdiv(h) * 0.7) * 8).floor % FOIL.length
        @pixels[y0 + row][x0 + col] = mix(FOIL[band], PANEL, 0.48)
      end
    end

    seed = Zlib.crc32(@name)
    14.times do |i|
      seed = (seed * 1103515245 + 12345) & 0x7fffffff
      col = 3 + seed % (w - 6)
      seed = (seed * 1103515245 + 12345) & 0x7fffffff
      row = 3 + seed % (h - 6)
      @pixels[y0 + row][x0 + col] = i.even? ? PAPER : ACCENT
    end
  end

  # Union of rects on a 10x10 grid, with the check centred: it spans x 2-7, y 3-6.
  OUTER = [ [ 3, 0, 4, 10 ], [ 1, 1, 8, 8 ], [ 0, 3, 10, 4 ] ].freeze
  INNER = [ [ 3, 1, 4, 8 ], [ 2, 2, 6, 6 ], [ 1, 3, 8, 4 ] ].freeze
  CHECK = [ [ 2, 4 ], [ 3, 5 ], [ 4, 6 ], [ 5, 5 ], [ 6, 4 ], [ 7, 3 ], [ 3, 4 ], [ 4, 5 ], [ 5, 4 ], [ 6, 3 ] ].freeze

  def seal
    unit = 5
    ox = CARD[:x] + (CARD[:w] - 10 * unit) / 2
    oy = CARD[:y] + 40
    OUTER.each { |x, y, w, h| fill(ox + x * unit, oy + y * unit, w * unit, h * unit, TEAL_DEEP) }
    INNER.each { |x, y, w, h| fill(ox + x * unit, oy + y * unit, w * unit, h * unit, ACCENT) }
    CHECK.each { |x, y| fill(ox + x * unit, oy + y * unit, unit, unit, INK) }
  end

  def copy
    left = 164
    text("OMARCHY VERIFIED", left, 34, ACCENT)
    fill(left, 48, 212, 2, TEAL_DEEP)

    y = 62
    wrap(@name, 18, 3).each do |line|
      text(line, left, y, PAPER, scale: 2)
      y += 18
    end

    y = [ y + 10, 126 ].max
    [ [ "CPU", @cpu ], [ "GPU", @gpu ], [ "OMARCHY", @version ] ].each do |label, value|
      text(label, left, y, MUTED)
      text(clip(value, 24), left + 60, y, PAPER)
      y += 14
    end

    text("#{@machines} #{@machines == 1 ? "MACHINE" : "MACHINES"}", left, 176, MUTED)
    text("OMAHCL.COM", WIDTH - 24 - width_of("OMAHCL.COM"), 176, ACCENT)
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

  def width_of(string, scale: 1)
    string.length * 6 * scale
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
