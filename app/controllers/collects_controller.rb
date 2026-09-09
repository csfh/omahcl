class CollectsController < ApplicationController
  allow_unauthenticated_access only: :show
  skip_forgery_protection only: :show

  def show
    script = Rails.root.join("lib/collectors/omarchy.sh").read
    script = script.sub("__MARKET_URL__", request.base_url)
    send_data script, filename: "omarchy-market-collect.sh", type: "text/plain; charset=utf-8", disposition: "inline"
  end
end
