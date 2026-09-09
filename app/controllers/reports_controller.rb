class ReportsController < ApplicationController
  allow_unauthenticated_access only: :create
  skip_forgery_protection only: :create
  rate_limit to: 30, within: 1.minute, only: :create, with: -> { head :too_many_requests }

  def create
    return head :payload_too_large if request.content_length.to_i > 64.kilobytes

    raw = parse_json_body
    report, token = Report.ingest(raw, ip: request.remote_ip)

    body = {
      public_id: report.public_id,
      model_url: hardware_model_url(report.model_slug)
    }
    body[:claim_url] = claim_report_url(report.public_id, token: token) if token
    render json: body, status: (report.previously_new_record? ? :created : :ok)
  rescue JSON::ParserError
    render json: { error: "invalid JSON" }, status: :bad_request
  rescue ReportSanitizer::Rejected => error
    render json: { error: error.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => error
    render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private
    def parse_json_body
      JSON.parse(request.raw_post)
    end
end
