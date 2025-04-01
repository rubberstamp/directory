class GuestMessagesController < ApplicationController
  before_action :set_profile, only: [:create]
  
  def new
    @guest_message = GuestMessage.new
    @guest_message.is_podcast_application = true
  end
  
  def create
    @guest_message = GuestMessage.new(guest_message_params)
    @guest_message.profile = @profile if @profile
    
    respond_to do |format|
      if @guest_message.save
        # Send notification emails
        GuestMessageMailer.sender_confirmation(@guest_message).deliver_later
        GuestMessageMailer.admin_notification(@guest_message).deliver_later
        
        # Auto-forward disabled for now
        # if @profile && @profile.auto_forward_messages
        #   GuestMessageMailer.forward_to_guest(@guest_message).deliver_later
        #   @guest_message.mark_as_forwarded!
        # end
        
        format.html { 
          flash[:success] = "Your message has been sent successfully."
          redirect_back(fallback_location: root_path)
        }
        format.json { render json: { success: true, message: "Message sent successfully" }, status: :created }
      else
        format.html { 
          flash[:error] = "There was a problem sending your message: #{@guest_message.errors.full_messages.join(', ')}"
          redirect_back(fallback_location: root_path)
        }
        format.json { render json: @guest_message.errors, status: :unprocessable_entity }
      end
    end
  end
  
  private
  
  def set_profile
    @profile = Profile.find(params[:profile_id]) if params[:profile_id].present?
  end
  
  def guest_message_params
    params.require(:guest_message).permit(:sender_name, :sender_email, :subject, :message, 
                                         :location, :practice_size, :specialty, :is_podcast_application)
  end
end
