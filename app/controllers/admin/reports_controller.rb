module Admin
  class ReportsController < BaseController
    def index
      @query = params[:q].to_s
      @claimed_filter = params[:claimed] if params[:claimed].in?(%w[yes no])
      @reports = Report.includes(:user, :listings).order(created_at: :desc).for_query(@query)
      @reports = @reports.claimed if @claimed_filter == "yes"
      @reports = @reports.where(user_id: nil) if @claimed_filter == "no"
    end

    def show
      @report = Report.includes(:user, :listings).find_by!(public_id: params[:public_id])
    end
  end
end
