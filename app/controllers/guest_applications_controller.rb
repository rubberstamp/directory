class GuestApplicationsController < ApplicationController
  def new
    @profile = Profile.new
  end

  def create
    @profile = Profile.new(profile_params)
    @profile.status = "applicant"

    if @profile.save
      # Notify admin about the new guest application
      admin_email = Rails.application.config.podcast_admin_email
      # AdminMailer.new_guest_application_notification(admin_email, @profile).deliver_now if defined?(AdminMailer)

      flash[:success] = "Thank you for your application! We'll review it and get back to you soon."
      redirect_to root_path
    else
      flash.now[:error] = "There was a problem with your application. Please correct the errors below."
      render :new, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:profile).permit(
      :name, :email, :phone, :company, :location, :headline, :bio,
      :website, :linkedin_url, :twitter_url, :facebook_url, :instagram_url,
      :practice_size, :podcast_objectives
    )
  end
end
