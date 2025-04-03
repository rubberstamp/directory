module Admin
  class PagesController < BaseController
    before_action :set_page, only: [:show, :edit, :update, :destroy]
    
    def index
      @pages = Page.all.order(position: :asc)
    end
    
    def show
    end
    
    def new
      @page = Page.new
    end
    
    def edit
    end
    
    def create
      @page = Page.new(page_params)
      
      if @page.save
        redirect_to admin_pages_path, notice: 'Page was successfully created.'
      else
        render :new
      end
    end
    
    def update
      if @page.update(page_params)
        redirect_to admin_pages_path, notice: 'Page was successfully updated.'
      else
        render :edit
      end
    end
    
    def destroy
      @page.destroy
      redirect_to admin_pages_path, notice: 'Page was successfully deleted.'
    end
    
    private
    
    def set_page
      @page = Page.find_by(id: params[:id]) || Page.find_by(slug: params[:id])
      raise ActiveRecord::RecordNotFound unless @page
    end
    
    def page_params
      params.require(:page).permit(:title, :slug, :content, :published, :position, :meta_description, :meta_keywords, :show_in_menu)
    end
  end
end