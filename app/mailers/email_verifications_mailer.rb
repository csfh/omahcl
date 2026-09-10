class EmailVerificationsMailer < ApplicationMailer
  def verify(user)
    @user = user
    mail subject: "Verify your Market email", to: user.email_address
  end
end
