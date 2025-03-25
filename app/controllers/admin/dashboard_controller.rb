class Admin::DashboardController < Admin::BaseController
  def index
    @profile_count = Profile.count
    @specialization_count = Specialization.count
  end
end
