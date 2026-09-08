module Admin
  class BaseController < ApplicationController
    before_action :require_admin

    private
      def require_admin
        unless current_user&.admin?
          redirect_to root_path, alert: "You are not allowed to do that."
        end
      end
  end
end
