module Admin
  class ReportsController < BaseController
    before_action :set_report, only: %i[show hide unhide]

    def index
      @query = params[:q].to_s
      @hidden_filter = params[:hidden] if params[:hidden].in?(%w[yes no])
      @reports = Report.order(created_at: :desc).for_query(@query)
      @reports = @reports.hidden if @hidden_filter == "yes"
      @reports = @reports.visible if @hidden_filter == "no"
    end

    def show
    end

    def hide
      @report.update!(hidden_at: Time.current) unless @report.hidden?
      redirect_to admin_report_path(@report.public_id), notice: "Report hidden from public pages."
    end

    def unhide
      @report.update!(hidden_at: nil)
      redirect_to admin_report_path(@report.public_id), notice: "Report is public again."
    end

    private
      def set_report
        @report = Report.find_by!(public_id: params[:public_id])
      end
  end
end
