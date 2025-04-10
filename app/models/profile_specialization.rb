class ProfileSpecialization < ApplicationRecord
  belongs_to :profile
  belongs_to :specialization

  validates :profile_id, uniqueness: { scope: :specialization_id }
end
