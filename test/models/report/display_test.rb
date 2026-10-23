require "test_helper"

class Report::DisplayTest < ActiveSupport::TestCase
  test "cpu names lose trademarks, clock speeds and filler words" do
    {
      "Intel(R) Core(TM) Ultra X7 358H" => "Intel Core Ultra X7 358H",
      "Intel(R) Core(TM) i7-8550U CPU @ 1.80GHz" => "Intel Core i7-8550U",
      "Intel(R) Core(TM)2 Duo CPU     P8600  @ 2.40GHz" => "Intel Core2 Duo P8600",
      "Intel(R) Xeon(R) CPU           W3680  @ 3.33GHz" => "Intel Xeon W3680",
      "12th Gen Intel(R) Core(TM) i7-1260P" => "12th Gen Intel Core i7-1260P",
      "AMD Ryzen 9 5900X 12-Core Processor" => "AMD Ryzen 9 5900X",
      "AMD Ryzen 7 7840U w/ Radeon 780M Graphics" => "AMD Ryzen 7 7840U",
      "AMD Ryzen 5 PRO 5650U with Radeon Graphics" => "AMD Ryzen 5 PRO 5650U",
      "AMD RYZEN AI MAX+ 395 w/ Radeon 8060S" => "AMD RYZEN AI MAX+ 395",
      "Apple M2" => "Apple M2",
      "Unknown CPU" => "Unknown CPU"
    }.each { |raw, shown| assert_equal shown, Report::Display.cpu(raw), raw }
  end

  test "the short cpu name drops the maker so it fits on a card" do
    assert_equal "Core Ultra X7 358H", Report::Display.cpu("Intel(R) Core(TM) Ultra X7 358H", short: true)
    assert_equal "Ryzen 7 7840U", Report::Display.cpu("AMD Ryzen 7 7840U w/ Radeon 780M Graphics", short: true)
    assert_equal "12th Gen Core i7-1260P", Report::Display.cpu("12th Gen Intel(R) Core(TM) i7-1260P", short: true)
    assert_equal "Apple M2", Report::Display.cpu("Apple M2", short: true)
  end

  test "gpu vendors get their short names" do
    assert_equal "Intel", Report::Display.gpu_vendor("Intel Corporation")
    assert_equal "NVIDIA", Report::Display.gpu_vendor("NVIDIA Corporation")
    assert_equal "AMD", Report::Display.gpu_vendor("Advanced Micro Devices, Inc. [AMD/ATI]")
    assert_equal "Apple", Report::Display.gpu_vendor("Apple")
    assert_equal "Moore Threads Technology", Report::Display.gpu_vendor("Moore Threads Technology Co., Ltd")
  end

  test "a gpu is its product name, with its maker unless short" do
    assert_equal "Intel Arc B390", Report::Display.gpu("Intel Corporation", "Panther Lake [Arc B390]")
    assert_equal "Arc B390", Report::Display.gpu("Intel Corporation", "Panther Lake [Arc B390]", short: true)
    assert_equal "NVIDIA GeForce RTX 3060", Report::Display.gpu("NVIDIA Corporation", "GA106 [GeForce RTX 3060]")
    assert_equal "Intel Iris Plus Graphics G7", Report::Display.gpu("Intel Corporation", "Iris Plus Graphics G7")
    assert_equal "Apple M2 GPU", Report::Display.gpu("Apple", "Apple M2 GPU")
  end

  test "a list of gpus is unique and skips blanks" do
    list = [ { "vendor" => "Intel Corporation", "name" => "HD Graphics 3000" }, { "vendor" => "Intel Corporation", "name" => "HD Graphics 3000" }, {} ]

    assert_equal [ "Intel HD Graphics 3000" ], Report::Display.gpus(list)
  end

  test "a model name does not repeat its vendor" do
    assert_equal "HP EliteBook 840 G4", Report::Display.model("HP", "HP EliteBook 840 G4")
    assert_equal "Dell Pro 14 PC14255", Report::Display.model("Dell", "Dell Pro 14 PC14255")
    assert_equal "Dell XPS 14 DA14260", Report::Display.model("Dell", "XPS 14 DA14260")
    assert_equal "Dell Dellwood 1", Report::Display.model("Dell", "Dellwood 1")
  end

  test "a Lenovo machine-type code gives way to its family name, keeping the code" do
    assert_equal "Lenovo ThinkPad X1 Carbon Gen 9 (20XXS2XU00)", Report::Display.model("Lenovo", "20XXS2XU00", "ThinkPad X1 Carbon Gen 9")
    assert_equal "Lenovo ThinkPad X220 (429143G)", Report::Display.model("Lenovo", "429143G", "ThinkPad  X220")
    assert_equal "Lenovo Legion 5 15AHP10 (83M0)", Report::Display.model("Lenovo", "83M0", "Legion 5 15AHP10")
    assert_equal "Lenovo ThinkPad X1 Carbon Gen 9", Report::Display.model("Lenovo", "20XXS2XU00", "ThinkPad X1 Carbon Gen 9", short: true)
  end

  test "a Lenovo code stays when the family adds nothing, and other vendors keep their product" do
    assert_equal "Lenovo 80HR", Report::Display.model("Lenovo", "80HR", "IDEAPAD")
    assert_equal "Lenovo 20XXS2XU00", Report::Display.model("Lenovo", "20XXS2XU00", nil)
    assert_equal "Lenovo 20XXS2XU00", Report::Display.model("Lenovo", "20XXS2XU00", "20XX S2XU00")
    assert_equal "Lenovo IdeaPad Z580", Report::Display.model("Lenovo", "IdeaPad Z580", "IDEAPAD Z580")
    assert_equal "ASUS X510UQR", Report::Display.model("ASUS", "X510UQR", "VivoBook")
    assert_equal "Samsung 550XDA", Report::Display.model("Samsung", "550XDA", "Notebook Plus2 Pro 2")
  end

  test "an Intel Mac identifier reads as its marketing name, keeping the identifier" do
    assert_equal "Apple MacBook Pro (Retina, 13-inch, Early 2015) · MacBookPro12,1", Report::Display.model("Apple", "MacBookPro12,1")
    assert_equal "MacBook Pro (13-inch, Early 2015)", Report::Display.model("Apple", "MacBookPro12,1", short: true)
    assert_equal "MacBook Pro (13-inch, 2018–2019)", Report::Display.model("Apple", "MacBookPro15,2", short: true)
    assert_equal "Apple iMac (21.5-inch, Mid 2011) · iMac12,1", Report::Display.model("Apple", "iMac12,1")
    assert_equal "Apple Mac Pro (2010–2012) · MacPro5,1", Report::Display.model("Apple", "MacPro5,1")
  end

  test "an identifier sold in several sizes or years shows what they share" do
    assert_equal "Apple iMac (2009) · iMac9,1", Report::Display.model("Apple", "iMac9,1")
    assert_equal "Apple MacBook Pro (Retina, 15-inch, 2012–2013) · MacBookPro10,1", Report::Display.model("Apple", "MacBookPro10,1")
  end

  test "a Mac without a table entry, an Asahi model and other vendors are shown as sent" do
    assert_equal "Apple MacBook7,1", Report::Display.model("Apple", "MacBook7,1")
    assert_equal "Apple MacBook Air (13-inch, M2, 2022)", Report::Display.model("Apple", "MacBook Air (13-inch, M2, 2022)")
    assert_equal "Dell MacBookPro12,1", Report::Display.model("Dell", "MacBookPro12,1")
  end

  test "every Mac name in the table starts with a Mac line and has no server or rack variant" do
    assert_operator Report::Display::MAC_MODELS.size, :>, 100
    Report::Display::MAC_MODELS.each do |id, name|
      assert_match(/\A[A-Za-z]+\d+,\d+\z/, id)
      assert_match(/\A(?:MacBook(?: Pro| Air)?|iMac(?: Pro)?|Mac mini|Mac Pro|Mac Studio)\b/, name, id)
      refute_match(/Server|Rack/, name, id)
    end
  end

  test "memory is the installed size that holds what the machine reports" do
    {
      (7.34 * Report::Display::GIB) => "8 GB", (15.2 * Report::Display::GIB) => "16 GB",
      (30.9 * Report::Display::GIB) => "32 GB", (62.3 * Report::Display::GIB) => "64 GB",
      (3.56 * Report::Display::GIB) => "4 GB", (122 * Report::Display::GIB) => "128 GB",
      (16 * Report::Display::GIB) => "16 GB", 0 => "Unknown"
    }.each { |bytes, shown| assert_equal shown, Report::Display.memory(bytes.to_i), bytes }
  end
end
