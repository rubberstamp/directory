class Page < ApplicationRecord
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }
  
  scope :published, -> { where(published: true) }
  scope :menu_items, -> { published.where(show_in_menu: true).order(position: :asc) }
  
  before_validation :set_slug, if: -> { slug.blank? && title.present? }
  
  def to_param
    slug
  end
  
  private
  
  def set_slug
    self.slug = title.parameterize
  end
end