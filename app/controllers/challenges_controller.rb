class ChallengesController < ApplicationController
  allow_unauthenticated_access only: :create
  skip_forgery_protection only: :create
  rate_limit to: 10, within: 1.minute, only: :create, with: -> { head :too_many_requests }

  def create
    nonce, challenge = Challenge.issue!
    render json: { nonce: nonce, expires_at: challenge.expires_at.iso8601 }
  end
end
