require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @report = ingest_report!(omarchy_payload(product: "ThinkPad X220"))
  end

  test "card shows the configuration with the Omarchy Verified seal for a single machine" do
    get card_path(@report.card_key)

    assert_response :success
    assert_select "[data-controller=holo-card] [data-holo-card-target=card][aria-label^='Omarchy Verified: '][aria-label*='X220']"
    assert_select "h2", /ThinkPad X220/
    assert_select "p", text: "Omarchy Verified"
    assert_select "dd", text: "Intel Core i5-2520M"
    assert_select "[style]", count: 0
    assert_select "a[href=?][download=?]", card_path(@report.card_key, format: :png), "#{@report.card_key}.png"
    assert_select "article", text: /machine/i, count: 0
    assert_no_match(/#{@report.public_id}|#{@report.instance_digest}/, response.body)
  end

  test "card png is a 1200x630 image with caching headers" do
    get card_path(@report.card_key, format: :png)

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal "\x89PNG\r\n\x1a\n".b, response.body.b[0, 8]
    assert_equal [ 1200, 630 ], response.body.b[16, 8].unpack("NN")
    assert_match(/public/, response.headers["Cache-Control"])
    assert_includes response.headers["Content-Disposition"], %(filename="#{@report.card_key}.png")

    get card_path(@report.card_key, format: :png), headers: { "If-None-Match" => response.headers["ETag"] }
    assert_response :not_modified
  end

  test "card has link preview tags pointing at its png" do
    get card_path(@report.card_key)

    assert_select "meta[property='og:image'][content=?]", card_url(@report.card_key, format: :png)
    assert_select "meta[property='og:image:width'][content='1200']"
    assert_select "meta[name='twitter:card'][content='summary_large_image']"
  end

  test "two machines of the same model and CPU share one card, another CPU gets its own" do
    same = ingest_report!(omarchy_payload(product: "ThinkPad X220", cpu: "  intel CORE i5-2520M "))
    other = ingest_report!(omarchy_payload(product: "ThinkPad X220", cpu: "Intel Core i7-2640M"))

    assert_equal @report.card_key, same.card_key
    assert_not_equal @report.card_key, other.card_key

    get card_path(other.card_key)
    assert_select "dd", text: "Intel Core i7-2640M"
  end

  test "card names the cpu and gpu the way people say them, and the png gets the short names" do
    report = ingest_report!(omarchy_payload(product: "XPS 14 DA14260", cpu: "Intel(R) Core(TM) Ultra X7 358H", instance_digest: "d" * 64)
      .deep_merge("hardware" => {
        "vendor" => "Dell Inc.", "memory_bytes" => (30.9 * 1024**3).to_i,
        "gpus" => [ { "vendor" => "Intel Corporation", "name" => "Panther Lake [Arc B390]" } ]
      }))

    get card_path(report.card_key)

    assert_select "dd", text: "Intel Core Ultra X7 358H"
    assert_select "dd", text: "Intel Arc B390"
    assert_select "dd", text: /Corporation/, count: 0

    get card_path(report.card_key, format: :png)
    assert_response :success
    assert_equal "image/png", response.media_type
  end

  test "card is not found for malformed, unknown and hidden keys" do
    get "/cards/not-a-key"
    assert_response :not_found

    get card_path("0" * 16)
    assert_response :not_found

    @report.update!(hidden_at: Time.current)
    get card_path(@report.card_key)
    assert_response :not_found
    get card_path(@report.card_key, format: :png)
    assert_response :not_found
  end
end
