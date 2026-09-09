module Me
  class ReportsController < ApplicationController
    def index
      @reports = current_user.reports.includes(:listings).order(claimed_at: :desc)
    end
  end
end
