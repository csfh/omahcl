class ReportsController < ApplicationController
  allow_unauthenticated_access only: :create
  skip_forgery_protection only: :create
  before_action :reject_oversized_body, only: :create
  rate_limit to: 30, within: 1.minute, only: :create, with: -> { head :too_many_requests }
  rate_limit to: 5, within: 1.minute, only: :create, name: "candidates", if: :candidate_post?, with: -> { head :too_many_requests }

  def create
    raw = parse_json_body
    report = Report.ingest(raw)

    known = Report.visible.where(model_slug: report.model_slug).distinct.count(:instance_digest)
    body = { public_id: report.public_id, known_machines: known }
    body[:model_url] = hardware_model_url(report.model_slug) if known.positive?
    render json: body, status: (report.previously_new_record? ? :created : :ok)
  rescue JSON::ParserError
    render json: { error: "invalid JSON" }, status: :bad_request
  rescue ReportSanitizer::Rejected => error
    render json: { error: error.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => error
    render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private
    def reject_oversized_body
      head :content_too_large if request.content_length.to_i > 64.kilobytes
    end

    def parse_json_body
      @parsed_body ||= JSON.parse(request.raw_post)
    end

    def candidate_post?
      body = parse_json_body
      body.is_a?(Hash) && body["source"] == "candidate"
    rescue JSON::ParserError
      false
    end
end
