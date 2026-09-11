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
  # 명시적 정렬이 없으면 Postgres 의 계획에 따라 순서가 흔들린다 - 조인 테이블이
  # 작을 때는 태그 테이블을 seq scan 하는 hash join 이라 물리 순서가 나오고,
  # 통계가 쌓이면 조인 테이블을 도는 nested loop 로 바뀌어 붙인 순서가 나온다.
  # 즉 같은 코드가 같은 데이터에서 요청마다 다른 순서를 낼 수 있었다.
  #
  # 정렬 키를 기본키 오름차순으로 고정한다. 근거 둘:
  #
  # 1. 정본(FastAPI)이 조회에서 내는 순서와 같다. 실측: 태그를 [둘, 하나] 순서로
  #    붙여도 GET 응답은 [하나, 둘] 이다 - 정본은 붙인 순서를 지키지 않는다.
  #    JSON:API 는 to-many 관계의 순서를 규정하지 않지만, 이 템플릿군은 하나의
  #    공개 계약을 공유하므로 순서가 갈리면 같은 화면이 백엔드마다 다르게 보인다.
  # 2. 이 저장소가 이미 `.../examples/:id/tags` 관련 자원 라우트에서 같은 키로
  #    정렬한다(JsonapiRelationships#related_collection_payload). 그것이 없으면
  #    같은 관계를 어느 라우트로 묻느냐에 따라 순서가 달라진다.
  has_many :tags, -> { order(:id) }, through: :example_taggings, source: :example_tag

  validates :title, length: { minimum: 1, maximum: 200 }, exclusion: { in: [ nil ] }
  validates :score, numericality: { only_integer: true, in: 0..100 }
end
