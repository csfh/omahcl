module Admin
  class DashboardsController < BaseController
    def show
      since = 7.days.ago

      @collection_count = Report.count
      @collections_created_week = Report.created_since(since).count
      @collections_updated_week = Report.updated_since(since).count
      @model_count = Report.distinct.count(:model_slug)
      @claimed_report_count = Report.claimed.count
      @unclaimed_report_count = Report.unclaimed.count
      @claimed_week = Report.claimed_since(since).count
      @recent_reports = Report.includes(:user).order(updated_at: :desc).limit(8)

      @listing_counts = Listing.statuses.keys.index_with { 0 }.merge(Listing.group(:status).count)
      @listings_published_week = Listing.where(status: :published, created_at: since..).count

      @open_challenge_count = Challenge.still_open.count
      @consumed_challenge_count = Challenge.consumed.count
      @expired_challenge_count = Challenge.expired.count
      @challenges_week = Challenge.created_since(since).count

      @user_count = User.count
      @verified_user_count = User.where.not(email_verified_at: nil).count
      @admin_count = User.where(admin: true).count
      @destination_count = DonationDestination.count
    end
  end
end
