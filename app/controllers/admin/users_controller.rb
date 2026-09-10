module Admin
  class UsersController < BaseController
    before_action :set_user, only: %i[show verify_email grant_admin revoke_admin password_reset destroy]

    def index
      @query = params[:q].to_s
      @admin_filter = params[:admin] if params[:admin].in?(%w[yes no])
      @users = User.includes(:reports).order(:email_address)
      if @query.present?
        @users = @users.where("email_address ILIKE ?", "%#{User.sanitize_sql_like(@query.strip)}%")
      end
      @users = @users.where(admin: @admin_filter == "yes") if @admin_filter
    end

    def show
      @reports = @user.reports.order(created_at: :desc)
      @listings = @user.listings.includes(:report, :donation_destination).order(created_at: :desc)
    end

    def verify_email
      @user.verify_email!
      redirect_to admin_user_path(@user), notice: "Email marked as verified."
    end

    def grant_admin
      @user.update!(admin: true)
      redirect_to admin_user_path(@user), notice: "Admin access granted."
    end

    def revoke_admin
      if @user.last_admin?
        redirect_to admin_user_path(@user), alert: "The last admin cannot be removed."
        return
      end

      @user.update!(admin: false)
      redirect_to admin_user_path(@user), notice: "Admin access revoked."
    end

    def password_reset
      PasswordsMailer.reset(@user).deliver_later
      redirect_to admin_user_path(@user), notice: "Password reset email queued."
    end

    def destroy
      if @user == current_user
        redirect_to admin_user_path(@user), alert: "You cannot delete your own account."
        return
      end
      if @user.last_admin?
        redirect_to admin_user_path(@user), alert: "The last admin cannot be removed."
        return
      end

      @user.close_open_listings!
      @user.destroy!
      redirect_to admin_users_path, notice: "Account removed."
    end

    private
      def set_user
        @user = User.find(params[:id])
      end
  end
end
