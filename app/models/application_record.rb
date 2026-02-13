class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Ransack: 모든 컬럼/관계 허용 (실제 필터 제어는 컨트롤러의 filter_attributes에서)
  def self.ransackable_attributes(auth_object = nil)
    column_names + _ransackers.keys
  end

  def self.ransackable_associations(auth_object = nil)
    reflect_on_all_associations.map { |a| a.name.to_s }
  end
end
