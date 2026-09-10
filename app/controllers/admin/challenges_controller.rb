module Admin
  class ChallengesController < BaseController
    def index
      @status = params[:status] if params[:status].in?(%w[open consumed expired])
      @challenges = Challenge.newest_first
      @challenges = @challenges.still_open if @status == "open"
      @challenges = @challenges.consumed if @status == "consumed"
      @challenges = @challenges.expired if @status == "expired"
    end

    def show
      @challenge = Challenge.find(params[:id])
    end
  end
end
