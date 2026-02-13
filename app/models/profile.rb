class Profile < ApplicationRecord
  # Enums
  enum :job_seeking_status, {
    actively_seeking: 0,
    open_to_offers: 1,
    not_seeking: 2
  }

  enum :start_work, {
    within_one_week: 0,
    within_one_month: 1,
    one_month_after_offer: 2,
    negotiable: 3
  }

  # Associations
  # User from Auth DB via FDW
  belongs_to :user, class_name: "Auth::User", foreign_key: "user_id", optional: true
  belongs_to :job_category, optional: true
  belongs_to :nationality, class_name: 'Country', foreign_key: 'nationality_id', optional: true

  has_many :profile_highlights, dependent: :destroy
  has_many :profile_jobs, dependent: :destroy
  has_many :jobs, through: :profile_jobs
  has_many :profile_languages, dependent: :destroy
  has_many :profile_links, dependent: :destroy
  has_many :profile_projects, dependent: :destroy
  has_many :profile_experiences, dependent: :destroy
  has_many :profile_freelance_experiences, dependent: :destroy
  has_many :profile_educations, dependent: :destroy
  has_many :profile_attachments, dependent: :destroy
  has_many :featured_profiles, dependent: :destroy
  has_many :job_applications, dependent: :destroy

  # Callbacks
  before_save :calculate_completeness, if: :completeness_fields_changed?

  # Validations
  validates :user_id, presence: true, uniqueness: true
  validates :email_public, inclusion: { in: [true, false] }
  validates :overall_completeness, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :required_completeness, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :total_years_of_experience, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :weight, presence: true, numericality: { only_integer: true }
  validates :name, length: { maximum: 100 }, allow_blank: true

  private

  def calculate_completeness
    # Required completeness (7 required fields, each ~14.3%)
    required_fields = [
      name.present?,
      introduction.present?,
      job_category_id.present?,
      skills.present? && skills.any?,
      employment_type.present? && employment_type.is_a?(Hash) && employment_type.values.any? { |v| v.is_a?(Hash) && v.values.any? { |sv| sv.is_a?(Hash) && sv["value"] == true } },
      work_type.present? && work_type.any?,
      profile_image.present?
    ]
    filled_required = required_fields.count(true)
    self.required_completeness = ((filled_required.to_f / required_fields.size) * 100).round

    # Overall completeness: required fields (70%, each 10%) + optional fields (30%, each 5%)
    overall_score = filled_required * 10

    overall_score += 5 if about.present?
    overall_score += 5 if association_any?(:profile_experiences)
    overall_score += 5 if association_any?(:profile_educations)
    overall_score += 5 if association_any?(:profile_projects)
    overall_score += 5 if association_any?(:profile_links)
    overall_score += 5 if association_any?(:profile_highlights)

    self.overall_completeness = [overall_score, 100].min
  end

  COMPLETENESS_FIELDS = %w[
    name introduction job_category_id skills employment_type
    work_type profile_image about
  ].freeze

  def completeness_fields_changed?
    new_record? || (changed & COMPLETENESS_FIELDS).any?
  end

  def association_any?(name)
    if association(name).loaded?
      public_send(name).any?
    else
      public_send(name).exists?
    end
  end
end
