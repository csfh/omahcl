require "test_helper"

class SeoTest < ActionDispatch::IntegrationTest
  test "every public page has a description, a canonical address and link-preview tags" do
    ingest_report!

    [ root_path, hardware_models_path, privacy_path ].each do |path|
      get path

      assert_select "meta[name=description][content]", count: 1
      assert_select "link[rel=canonical][href=?]", "http://www.example.com#{path}"
      assert_select "meta[property='og:title']", count: 1
      assert_select "meta[property='og:description']", count: 1
      assert_select "meta[name='twitter:card'][content=summary]"
    end
  end

  test "a search page is canonical to the list, without the query" do
    get hardware_models_path(q: "thinkpad")

    assert_select "link[rel=canonical][href=?]", "http://www.example.com/models"
  end

  test "a model page keeps its card tags once, with a description" do
    report = ingest_report!

    get hardware_model_path(report.model_slug)

    assert_select "meta[name=description][content*=?]", "reported running Omarchy"
    assert_select "meta[property='og:title']", count: 1
    assert_select "meta[property='og:image']", count: 1
    assert_select "meta[name='twitter:card'][content=summary_large_image]"
    assert_select "link[rel=canonical]", count: 1
  end

  test "the brand link is a full-size tap target" do
    get root_path

    assert_select "header a.min-h-11", text: "Omarchy HCL"
  end

  test "the privacy page gives the delete command as a copyable block" do
    get privacy_path

    assert_select "#deleting ~ div [data-controller=clipboard] code", text: /\/delete \| bash/
  end

  test "the sitemap lists the pages and each visible model, not hidden ones" do
    shown = ingest_report!(omarchy_payload(product: "ThinkPad X220"))
    ingest_report!(omarchy_payload(product: "ThinkPad X230", instance_digest: "c" * 64)).update!(hidden_at: Time.current)

    get sitemap_path(format: :xml)

    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_equal [ "max-age=3600", "public" ], response.headers["Cache-Control"].split(", ").sort
    urls = Nokogiri::XML(response.body).remove_namespaces!.xpath("//url/loc").map(&:text)
    assert_includes urls, "http://www.example.com/"
    assert_includes urls, "http://www.example.com/models"
    assert_includes urls, hardware_model_url(shown.model_slug)
    assert_equal 1, urls.count { |url| url.include?("/models/") }
    assert_not_includes response.body, "x230"
  end

  test "robots.txt points at the sitemap" do
    assert_includes File.read(Rails.public_path.join("robots.txt")), "Sitemap: https://omahcl.com/sitemap.xml"
  end
end
