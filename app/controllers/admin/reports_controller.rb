module Admin
  class ReportsController < BaseController
    def index
      @query = params[:q].to_s
      @reports = Report.order(created_at: :desc).for_query(@query)
    end

    def show
      @report = Report.find_by!(public_id: params[:public_id])
    end
  end
end
