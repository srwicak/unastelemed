class HospitalAffiliation < ApplicationRecord
  belongs_to :medical_staff
  belongs_to :hospital
end
