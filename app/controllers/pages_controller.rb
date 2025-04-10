class PagesController < ApplicationController
  def show
    @page = Page.published.find_by!(slug: params[:id])
  rescue ActiveRecord::RecordNotFound
    raise ActionController::RoutingError.new("Not Found")
  end
end
