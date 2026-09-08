# frozen_string_literal: true

class Example < ApplicationRecord
  # validate: true 가 없으면 선언 밖 값을 대입하는 순간 ArgumentError 가 나고,
  # 그것은 rescue_from StandardError 에 걸려 500 이 된다. 계약상 이 자리는
  # 422 VALIDATION_ERROR 에 source.pointer=/data/attributes/status 다 - 클라이언트가
  # 보낸 값이 잘못된 것이지 서버가 고장난 것이 아니다.
  #
  # validate: true 는 대입을 raise 없이 받아 두고 검증에서 잡는다. 그래야
  # save! 가 RecordInvalid 를 내고 JsonapiErrors#render_record_invalid 가
  # 속성 이름에서 포인터를 만든다.
  enum :status, { draft: "draft", active: "active", archived: "archived" }, prefix: true, validate: true

  belongs_to :category, class_name: "ExampleCategory", optional: true
  has_many :example_taggings, dependent: :destroy
  has_many :tags, through: :example_taggings, source: :example_tag

  validates :title, presence: true, length: { maximum: 200 }
  validates :score, numericality: { only_integer: true, in: 0..100 }
end
