class Room < ApplicationRecord
  has_many :reservations
  
  validates :name, presence: true, uniqueness: true
  validates :number, presence: true, uniqueness: true
end