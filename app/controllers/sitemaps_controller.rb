# Public pages for search engines: home, the lists, and one page per vendor and model. Hidden
# machines are left out, and a model whose every machine is hidden has no page.
class SitemapsController < ApplicationController
  allow_unauthenticated_access

  def show
    @models = Report.visible.group(:model_slug).maximum(:updated_at).sort
    @vendors = Report::Stats.new.vendors.map { |row| Report::Vendor.slug(row.label) }.reject(&:blank?).uniq.sort
    expires_in 1.hour, public: true
    respond_to { |format| format.xml }
  end
end
