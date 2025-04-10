class Admin::SpecializationsController < Admin::BaseController
  before_action :set_specialization, only: [ :show, :edit, :update, :destroy ]

  def index
    @specializations = Specialization.all.order(:name)
  end

  def show
  end

  def new
    @specialization = Specialization.new
  end

  def create
    @specialization = Specialization.new(specialization_params)

    if @specialization.save
      redirect_to admin_specializations_path, notice: "Specialization was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @specialization.update(specialization_params)
      redirect_to admin_specializations_path, notice: "Specialization was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @specialization.profiles.any?
      redirect_to admin_specializations_path, alert: "Cannot delete specialization with associated profiles."
    else
      @specialization.destroy
      redirect_to admin_specializations_path, notice: "Specialization was successfully deleted."
    end
  end

  private

  def set_specialization
    @specialization = Specialization.find(params[:id])
  end

  def specialization_params
    params.require(:specialization).permit(:name, :description)
  end
end
