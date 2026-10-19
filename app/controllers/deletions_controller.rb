class DeletionsController < ApplicationController
  allow_unauthenticated_access only: :create
  skip_forgery_protection only: :create
  before_action :reject_oversized_body, only: :create
  rate_limit to: 10, within: 1.minute, only: :create, with: -> { head :too_many_requests }

  def create
    render json: { deleted: Report.erase(JSON.parse(request.raw_post)) }
  rescue JSON::ParserError
    render json: { error: "invalid JSON" }, status: :bad_request
  rescue ReportSanitizer::Rejected => error
    render json: { error: error.message }, status: :unprocessable_entity
  end
end
