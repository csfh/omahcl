xml.instruct!
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  [ root_path, hardware_models_path, privacy_path ].each do |path|
    xml.url { xml.loc site_url(path) }
  end
  @models.each do |slug, updated_at|
    xml.url do
      xml.loc site_url(hardware_model_path(slug))
      xml.lastmod updated_at.utc.iso8601
    end
  end
end
