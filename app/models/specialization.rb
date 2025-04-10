class Specialization < ApplicationRecord
  has_many :profile_specializations, dependent: :destroy
  has_many :profiles, through: :profile_specializations

  validates :name, presence: true, uniqueness: true
end
