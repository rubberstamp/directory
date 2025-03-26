class Admin::DashboardController < Admin::BaseController
  def index
    @profile_count = Profile.count
    @specialization_count = Specialization.count
    @new_messages_count = GuestMessage.where(status: GuestMessage::STATUSES[:new]).count
    @total_messages_count = GuestMessage.count
  end
end
