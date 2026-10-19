class CollectsController < ApplicationController
  # The URL is pasted into a script that people pipe to bash, so anything beyond
  # a plain origin could run as shell code.
  PLAIN_ORIGIN = %r{\Ahttps?://[a-z0-9.-]+(:\d+)?\z}i

  SCRIPTS = %w[collect delete].freeze

  allow_unauthenticated_access only: :show
  skip_forgery_protection only: :show

  def show
    return head :bad_request unless request.base_url.match?(PLAIN_ORIGIN)

    # The routes set :script. Only a fixed word ever reaches the script.
    name = SCRIPTS.find { |candidate| candidate == params[:script] }
    return head :not_found unless name

    script = Rails.root.join("lib/collectors/omarchy.sh").read
    script = script.sub("__OMAHCL_URL__", request.base_url).sub("__OMAHCL_ACTION__", name)
    send_data script, filename: "#{name}.sh", type: "text/plain; charset=utf-8", disposition: "inline"
  end
end
