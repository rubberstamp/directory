class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :check_admin
  
  layout 'admin'
  
  private
  
  def check_admin
    unless current_user.admin?
      flash[:alert] = "You must be an admin to access this section"
      redirect_to root_path
    end
  end
end