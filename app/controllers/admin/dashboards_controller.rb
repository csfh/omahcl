module Admin
  class DashboardsController < BaseController
    def show
      since = 7.days.ago

      @collection_count = Report.count
      @collections_created_week = Report.created_since(since).count
      @collections_updated_week = Report.updated_since(since).count
      @model_count = Report.distinct.count(:model_slug)
      @recent_reports = Report.order(updated_at: :desc).limit(8)

      @open_challenge_count = Challenge.still_open.count
      @consumed_challenge_count = Challenge.consumed.count
      @expired_challenge_count = Challenge.expired.count
      @challenges_week = Challenge.created_since(since).count

      @user_count = User.count
      @admin_count = User.where(admin: true).count
    end
  end
end
