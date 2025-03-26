class Admin::GuestMessagesController < Admin::BaseController
  before_action :set_guest_message, only: [:show, :edit, :update, :destroy, :forward]

  def index
    @guest_messages = GuestMessage.includes(:profile).order(created_at: :desc)
    @guest_messages = @guest_messages.where(status: params[:status]) if params[:status].present?
    @guest_messages = @guest_messages.where(profile_id: params[:profile_id]) if params[:profile_id].present?
    @guest_messages = @guest_messages.page(params[:page]).per(20)
  end

  def show
  end

  def edit
  end

  def update
    if @guest_message.update(guest_message_params)
      redirect_to admin_guest_message_path(@guest_message), notice: 'Guest message was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @guest_message.destroy
    redirect_to admin_guest_messages_path, notice: 'Guest message was successfully deleted.'
  end

  def forward
    if @guest_message.forward_manually
      # Email forwarding disabled for now
      # GuestMessageMailer.forward_to_guest(@guest_message).deliver_later
      
      # Still mark as forwarded for tracking purposes
      @guest_message.update(status: 'forwarded', forwarded_at: Time.current)
      redirect_to admin_guest_message_path(@guest_message), notice: 'Message marked as forwarded. (Note: Actual email delivery is currently disabled)'
    else
      redirect_to admin_guest_message_path(@guest_message), alert: 'Unable to forward message. Guest has disabled messages or has no forwarding email.'
    end
  end

  private

  def set_guest_message
    @guest_message = GuestMessage.find(params[:id])
  end

  def guest_message_params
    params.require(:guest_message).permit(:admin_notes, :status)
  end
end