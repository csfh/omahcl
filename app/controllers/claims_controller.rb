class ClaimsController < ApplicationController
  def new
    @report = Report.find_by!(public_id: params[:public_id])
    @token = params[:token].to_s
    unless @report.claimable?(@token)
      redirect_to root_path, alert: "This claim link is invalid or has expired."
    end
  end

  def create
    @report = Report.find_by!(public_id: params[:public_id])
    @token = params[:token].to_s
    @report.claim!(user: current_user, token: @token)
    redirect_to me_machines_path, notice: "This machine is now attached to your account."
  rescue Report::ClaimRejected => error
    redirect_to me_machines_path, alert: error.message
  rescue ActiveRecord::RecordInvalid
    redirect_to root_path, alert: "This claim link is invalid or has expired."
  end
end
