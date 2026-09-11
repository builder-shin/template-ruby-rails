# These stable identifiers and values mirror the shared FastAPI seed graph.
# Re-running seeds repairs seed-owned scalar values and the canonical linkage,
# while leaving unrelated application rows and user-added tag linkages intact.
ActiveRecord::Base.transaction do
  ExampleCategory.upsert_all(
    [ { id: "00000000-0000-4000-8000-000000000001", name: "기본 카테고리" } ],
    unique_by: :id,
    update_only: [ :name ],
    record_timestamps: true
  )
  ExampleTag.upsert_all(
    [ { id: "00000000-0000-4000-8000-000000000002", name: "기본 태그" } ],
    unique_by: :id,
    update_only: [ :name ],
    record_timestamps: true
  )
  Example.upsert_all(
    [
      {
        id: "00000000-0000-4000-8000-000000000003",
        title: "JSON:API 예시",
        description: "JSON:API와 CRUD 동작을 확인하기 위한 기본 데이터입니다.",
        status: "active",
        score: 90,
        category_id: "00000000-0000-4000-8000-000000000001"
      }
    ],
    unique_by: :id,
    update_only: %i[title description status score category_id],
    record_timestamps: true
  )
  ExampleTagging.insert_all(
    [
      {
        example_id: "00000000-0000-4000-8000-000000000003",
        tag_id: "00000000-0000-4000-8000-000000000002"
      }
    ],
    unique_by: %i[example_id tag_id]
  )
end
