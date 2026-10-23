xml.instruct!
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  [ root_url, hardware_models_url, privacy_url ].each do |url|
    xml.url { xml.loc url }
  end
  @models.each do |slug, updated_at|
    xml.url do
      xml.loc hardware_model_url(slug)
      xml.lastmod updated_at.utc.iso8601
    end
  end
end
