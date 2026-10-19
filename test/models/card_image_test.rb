require "test_helper"

class CardImageTest < ActiveSupport::TestCase
  def png(**overrides)
    CardImage.new(name: "ThinkPad X220", cpu: "Intel Core i5", gpu: "Intel HD", version: "4.0.2", **overrides).png
  end

  test "renders a valid PNG that decodes to the full image" do
    data = png.b

    assert_equal "\x89PNG\r\n\x1a\n".b, data[0, 8]
    idat = data[data.index("IDAT") + 4, data.bytesize]
    raw = Zlib::Inflate.new.inflate(idat)
    assert_equal 630 * (1 + 1200 * 3), raw.bytesize
  end

  test "survives long, accented and unsupported names" do
    assert png(name: "Ünïcode Machine 日本語 " * 8, cpu: "x" * 200, gpu: "").present?
  end

  test "output is deterministic for the same input" do
    assert_equal png, png
    assert_not_equal png, png(version: "4.1.0")
  end
end
