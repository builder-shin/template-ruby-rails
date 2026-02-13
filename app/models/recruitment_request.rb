# frozen_string_literal: true

class RecruitmentRequest < ApplicationRecord
  # Enum for status
  enum :status, { pending: 0, contacted: 1, completed: 2 }

  # Validations
  validates :company_name, presence: { message: "기업명을 입력해주세요" }
  validates :contact_name, presence: { message: "담당자 이름을 입력해주세요" }
  validates :email, presence: { message: "이메일을 입력해주세요" },
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "올바른 이메일 형식이 아닙니다" }
  validates :phone, presence: { message: "연락처를 입력해주세요" }
  validates :message, presence: { message: "채용 의뢰 내용을 입력해주세요" }
end
