class Page < ApplicationRecord
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }
  
  scope :published, -> { where(published: true) }
  scope :menu_items, -> { published.where(show_in_menu: true).order(position: :asc) }
  
  before_validation :set_slug, if: -> { slug.blank? && title.present? }
  
  # Default to HTML format for existing pages
  attribute :content_format, :string, default: "html"
  
  validates :content_format, inclusion: { in: %w[html markdown] }
  
  def to_param
    slug
  end
  
  def formatted_content
    if content_format == "markdown"
      # Let the helper handle the markdown rendering
      # This will be called from the view using a helper method
      content
    else
      # For HTML format, return as is
      content
    end
  end
  
  private
  
  def set_slug
    self.slug = title.parameterize
  end
end