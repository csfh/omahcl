class EmailVerificationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create show]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    if (user = User.find_by(email_address: params[:email_address])) && !user.email_verified?
      EmailVerificationsMailer.verify(user).deliver_later
    end

    redirect_to new_session_path, notice: "If that account needs verification, we sent a new link."
  end

  def show
    user = User.find_by_email_verification_token!(params[:token])
    user.verify_email!
    start_new_session_for user
    redirect_to after_authentication_url, notice: "Welcome to Market. Your email is verified."
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_session_path, alert: "That verification link is invalid or has expired."
  end
end
