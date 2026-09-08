module Me
  class MachinesController < ApplicationController
    def index
      @machines = current_user.machines.includes(:report, :listings).order(created_at: :desc)
    end
  end
end
