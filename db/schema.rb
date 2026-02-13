# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_07_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "postgres_fdw"
  enable_extension "uuid-ossp"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "application_context_references", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false, comment: "생성 시간"
    t.uuid "job_category_id", null: false, comment: "직군 ID"
    t.string "reference", null: false, comment: "적용 맥락"
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false, comment: "수정 시간"
    t.index ["job_category_id"], name: "IDX_6e168fbb59ea943d45a621ea2e"
    t.index ["reference"], name: "IDX_6d687fc0ca8a737fa852ca75c8"
  end

  create_table "blog_author_permission", comment: "블로그 작성 권한 관리 테이블", force: :cascade do |t|
    t.uuid "author_id", null: false
    t.string "author_type", limit: 20, null: false
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "processed_at", precision: nil
    t.uuid "processed_by"
    t.datetime "requested_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "status", limit: 20, default: "pending", null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["author_id"], name: "idx_blog_author_permission_author_id"
    t.index ["author_type"], name: "idx_blog_author_permission_author_type"
    t.index ["requested_at"], name: "idx_blog_author_permission_requested_at"
    t.index ["status"], name: "idx_blog_author_permission_status"
    t.check_constraint "author_type::text = ANY (ARRAY['personal'::character varying::text, 'enterprise'::character varying::text])", name: "blog_author_permission_author_type_check"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'approved'::character varying::text, 'rejected'::character varying::text])", name: "blog_author_permission_status_check"
    t.unique_constraint ["author_type", "author_id"], name: "unique_author"
  end

  create_table "blog_category", comment: "블로그 카테고리 테이블 (2단계 계층)", force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "level", limit: 2, default: 1, null: false
    t.string "name", limit: 128, null: false
    t.bigint "parent_id"
    t.string "slug", limit: 128, null: false
    t.integer "sort_order", default: 0, null: false
    t.string "status", limit: 20, default: "active", null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["parent_id"], name: "idx_blog_category_parent_id"
    t.index ["slug"], name: "idx_blog_category_slug"
    t.index ["status"], name: "idx_blog_category_status"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'inactive'::character varying::text])", name: "blog_category_status_check"
    t.unique_constraint ["slug"], name: "blog_category_slug_key"
  end

  create_table "blog_post", comment: "블로그 게시글 테이블", force: :cascade do |t|
    t.uuid "author_id", null: false
    t.string "author_type", limit: 20, null: false
    t.text "content", null: false
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "description"
    t.string "main_image", limit: 1024
    t.integer "main_image_size", default: 0, null: false
    t.text "meta_description"
    t.datetime "publish_date", precision: nil
    t.string "slug", limit: 512, null: false
    t.string "status", limit: 20, default: "draft", null: false
    t.json "tags"
    t.string "title", limit: 256, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "views", default: 0, null: false
    t.index "to_tsvector('simple'::regconfig, (((((COALESCE(title, ''::character varying))::text || ' '::text) || COALESCE(description, ''::text)) || ' '::text) || COALESCE(content, ''::text)))", name: "idx_blog_post_fulltext", using: :gin
    t.index ["author_id"], name: "idx_blog_post_author_id"
    t.index ["author_type"], name: "idx_blog_post_author_type"
    t.index ["publish_date"], name: "idx_blog_post_publish_date"
    t.index ["slug"], name: "idx_blog_post_slug"
    t.index ["status"], name: "idx_blog_post_status"
    t.check_constraint "author_type::text = ANY (ARRAY['personal'::character varying::text, 'enterprise'::character varying::text])", name: "blog_post_author_type_check"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'published'::character varying::text, 'hidden'::character varying::text, 'deleted'::character varying::text])", name: "blog_post_status_check"
    t.unique_constraint ["slug"], name: "blog_post_slug_key"
  end

  create_table "blog_post_category", primary_key: ["blog_post_id", "category_id"], comment: "블로그 게시글-카테고리 매핑 테이블", force: :cascade do |t|
    t.bigint "blog_post_id", null: false
    t.bigint "category_id", null: false
  end

  create_table "blog_view", comment: "블로그 조회 기록 테이블", force: :cascade do |t|
    t.bigint "blog_post_id", null: false
    t.string "ip_address", limit: 45
    t.uuid "user_id"
    t.datetime "viewed_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["blog_post_id"], name: "idx_blog_view_blog_post_id"
    t.index ["user_id"], name: "idx_blog_view_user_id"
    t.index ["viewed_at"], name: "idx_blog_view_viewed_at"
  end

  create_table "career_hub_categories", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.uuid "category_idx", default: -> { "uuid_generate_v4()" }, null: false
    t.string "color", limit: 50
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.text "description"
    t.integer "display_order", default: 0, null: false
    t.string "icon_name", limit: 150
    t.string "icon_url", limit: 2048
    t.string "key", limit: 100, null: false
    t.integer "level", limit: 2, null: false
    t.string "name", limit: 255, null: false
    t.uuid "parent_id"
    t.uuid "parent_idx"
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.boolean "visible", default: true, null: false
    t.index ["key"], name: "IDX_career_hub_categories_key", unique: true
    t.index ["level"], name: "IDX_career_hub_categories_level"
    t.index ["parent_id"], name: "IDX_career_hub_categories_parent_id"
    t.unique_constraint ["category_idx"], name: "UQ_career_hub_categories_categoryIdx"
  end

  create_table "career_hub_communities", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.timestamptz "approved_at"
    t.uuid "category_id"
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.text "description"
    t.text "duration"
    t.jsonb "intro_content"
    t.integer "join_policy"
    t.uuid "leader_id"
    t.integer "max_participants"
    t.integer "participants_count", default: 0, null: false
    t.jsonb "questions", default: [], null: false
    t.text "schedule"
    t.string "slug", limit: 255
    t.integer "status"
    t.uuid "subcategory_id"
    t.jsonb "tags", default: [], null: false
    t.string "thumbnail_url", limit: 2048
    t.string "title", limit: 255, null: false
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.timestamptz "withdrawn_at"
    t.index ["approved_at"], name: "IDX_career_hub_communities_approved_at"
    t.index ["category_id"], name: "IDX_career_hub_communities_category_id"
    t.index ["leader_id"], name: "IDX_career_hub_communities_leader_id"
    t.index ["slug"], name: "IDX_career_hub_communities_slug", unique: true, where: "(slug IS NOT NULL)"
    t.index ["subcategory_id"], name: "IDX_career_hub_communities_subcategory_id"
  end

  create_table "career_hub_community_event_participants", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "company", limit: 255
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.string "email", limit: 255, null: false
    t.uuid "event_id"
    t.string "name", limit: 255, null: false
    t.string "phone", limit: 50
    t.text "requests"
    t.integer "status"
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.uuid "user_id"
    t.index ["email"], name: "IDX_career_hub_event_participants_email"
    t.index ["event_id"], name: "IDX_career_hub_event_participants_event_id"
    t.index ["user_id"], name: "IDX_career_hub_event_participants_user_id"
  end

  create_table "career_hub_community_events", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "community_id"
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.jsonb "description"
    t.timestamptz "end_at"
    t.string "event_type", limit: 50, null: false
    t.string "location", limit: 255
    t.string "location_type", limit: 50
    t.integer "max_participants"
    t.string "meeting_link", limit: 500
    t.integer "participants_count", default: 0, null: false
    t.integer "price", default: 0, null: false
    t.timestamptz "publish_at", comment: "예약 업로드 일시 (null이면 즉시 업로드)"
    t.timestamptz "registration_end_at"
    t.timestamptz "registration_start_at"
    t.timestamptz "review_notification_sent_at"
    t.timestamptz "review_reminder_sent_at"
    t.timestamptz "start_at"
    t.integer "status"
    t.jsonb "tags", default: [], null: false
    t.string "thumbnail_url", limit: 2048
    t.string "title", limit: 255, null: false
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.index ["community_id"], name: "index_career_hub_community_events_on_community_id"
    t.index ["status"], name: "index_career_hub_community_events_on_status"
  end

  create_table "career_hub_community_feed_likes", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.uuid "feed_id", null: false
    t.uuid "user_id", null: false
    t.index ["user_id", "feed_id"], name: "IDX_career_hub_likes_user_feed", unique: true
  end

  create_table "career_hub_community_feeds", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "author_id", null: false
    t.uuid "community_id", null: false
    t.text "content", null: false
    t.timestamptz "content_edited_at"
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.integer "likes_count", default: 0, null: false
    t.uuid "parent_id"
    t.boolean "pinned", default: false, null: false
    t.timestamptz "pinned_at"
    t.integer "replies_count", default: 0, null: false
    t.uuid "root_id"
    t.integer "status"
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.index ["author_id"], name: "IDX_career_hub_feeds_author"
    t.index ["community_id", "pinned", "created_at"], name: "IDX_career_hub_feeds_community_root", order: { pinned: :desc, created_at: :desc }, where: "(parent_id IS NULL)"
    t.index ["community_id"], name: "IDX_career_hub_feeds_community"
    t.index ["created_at"], name: "IDX_career_hub_feeds_created", order: :desc
    t.index ["parent_id"], name: "IDX_career_hub_feeds_parent"
    t.index ["root_id"], name: "IDX_career_hub_feeds_root"
  end

  create_table "career_hub_community_leaders", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "avatar_url", limit: 2048
    t.text "bio"
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.string "current_company", limit: 255
    t.string "current_position", limit: 255
    t.jsonb "detailed_bio"
    t.string "display_name", limit: 255
    t.jsonb "experiences", default: [], null: false
    t.string "name", limit: 255, null: false
    t.text "quote"
    t.jsonb "social_links", default: [], null: false
    t.integer "status"
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.uuid "user_id"
    t.boolean "verification_badge", default: false, null: false
    t.index ["user_id"], name: "IDX_career_hub_leaders_user_id"
  end

  create_table "career_hub_community_members", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.jsonb "answers", default: [], null: false
    t.uuid "community_id"
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.timestamptz "joined_at", default: -> { "now()" }, null: false
    t.string "role", limit: 50, default: "member", null: false
    t.integer "status"
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.uuid "user_id"
    t.index ["community_id"], name: "IDX_career_hub_members_community_id"
    t.index ["user_id"], name: "IDX_career_hub_members_user_id"
  end

  create_table "career_hub_event_reviews", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "content", null: false
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.timestamptz "deleted_at"
    t.uuid "event_id", null: false
    t.integer "rating", limit: 2, null: false
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.uuid "user_id", null: false
    t.index ["event_id"], name: "IDX_career_hub_event_reviews_event_id"
    t.index ["user_id", "event_id"], name: "IDX_career_hub_event_reviews_user_event", unique: true, where: "(deleted_at IS NULL)"
    t.index ["user_id"], name: "IDX_career_hub_event_reviews_user_id"
  end

  create_table "countries", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false, comment: "생성 시간"
    t.string "name", null: false, comment: "국가 이름"
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false, comment: "수정 시간"
    t.index ["name"], name: "IDX_fa1376321185575cf2226b1491", unique: true
  end

  create_table "email_templates", primary_key: "key", id: { type: :string, limit: 50 }, force: :cascade do |t|
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.text "description"
    t.boolean "is_enabled", default: true, null: false
    t.string "name", limit: 100, null: false
    t.string "sendgrid_template_id", limit: 100
    t.string "subject", limit: 255
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.index ["is_enabled"], name: "IDX_email_templates_is_enabled"
  end

  create_table "event_notification_schedules", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.string "email_subject", limit: 255, null: false
    t.boolean "enabled", default: true, null: false
    t.timestamptz "last_executed_at"
    t.string "name", limit: 100, null: false
    t.time "send_time"
    t.string "sendgrid_template_id", limit: 100, null: false
    t.integer "target_type"
    t.integer "trigger_type"
    t.integer "trigger_value", null: false
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.index ["enabled"], name: "IDX_event_notification_schedules_is_enabled"
  end

  create_table "featured_profiles", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false, comment: "생성 시간"
    t.integer "display_order", default: 0, null: false, comment: "노출 순서"
    t.boolean "is_active", default: true, null: false, comment: "활성화 여부"
    t.uuid "profile_id", null: false, comment: "프로필 ID"
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false, comment: "수정 시간"
    t.index ["display_order"], name: "IDX_8ae157342fdd9718939b0a6f3c"
    t.index ["is_active"], name: "IDX_fac5c3b26589fb87762c976288"
    t.index ["profile_id"], name: "IDX_a2eae56d3d6401ca3443973ada", unique: true
    t.unique_constraint ["profile_id"], name: "REL_a2eae56d3d6401ca3443973ada"
  end

  create_table "highlight_references", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false, comment: "생성 시간"
    t.integer "highlight_type"
    t.uuid "job_category_id", null: false, comment: "직군 ID"
    t.string "reference", null: false, comment: "하이라이트"
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false, comment: "수정 시간"
    t.index ["job_category_id"], name: "IDX_2802b70c3add45cacf70280538"
    t.index ["reference"], name: "IDX_5985b055dcbc89ce9f681f00f3"
  end

  create_table "job_applications", id: { type: :uuid, default: -> { "uuid_generate_v4()" }, comment: "지원서 고유 ID" }, force: :cascade do |t|
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.string "email", limit: 255, comment: "지원자 이메일"
    t.uuid "job_post_id", null: false, comment: "채용 공고 ID"
    t.string "phone", limit: 20, comment: "지원자 전화번호"
    t.timestamptz "processed_at", comment: "처리 완료 일시"
    t.uuid "profile_id", null: false, comment: "프로필 ID (지원자)"
    t.jsonb "profile_snapshot", null: false, comment: "지원 시점 프로필 스냅샷"
    t.timestamptz "profile_viewed_at", comment: "프로필 열람 일시"
    t.text "rejection_reason", comment: "불합격 사유"
    t.timestamptz "reviewed_at", comment: "검토 시작 일시"
    t.integer "status"
    t.timestamptz "submitted_at", null: false, comment: "지원 일시"
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.index ["job_post_id"], name: "IDX_job_applications_job_post_id"
    t.index ["profile_id"], name: "IDX_job_applications_profile_id"
    t.index ["submitted_at"], name: "IDX_job_applications_submitted_at"
    t.unique_constraint ["job_post_id", "profile_id"], name: "UQ_job_applications_job_post_profile"
  end

  create_table "job_categories", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false, comment: "생성 시간"
    t.string "name", null: false, comment: "직군 이름"
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false, comment: "수정 시간"
    t.index ["name"], name: "IDX_2e5f6c46d136907967008b9bb6", unique: true
  end

  create_table "job_post_categories", primary_key: ["job_post_id", "job_category_id"], force: :cascade do |t|
    t.uuid "job_category_id", null: false
    t.uuid "job_post_id", null: false
    t.index ["job_category_id"], name: "IDX_job_post_categories_job_category_id"
    t.index ["job_post_id"], name: "IDX_job_post_categories_job_post_id"
  end

  create_table "job_post_jobs", primary_key: ["job_post_id", "job_id"], force: :cascade do |t|
    t.uuid "job_id", null: false
    t.uuid "job_post_id", null: false
    t.index ["job_id"], name: "IDX_job_post_jobs_job_id"
    t.index ["job_post_id"], name: "IDX_job_post_jobs_job_post_id"
  end

  create_table "job_post_languages", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.uuid "job_post_id", null: false, comment: "채용 공고 ID"
    t.string "language", null: false, comment: "언어명"
    t.integer "proficiency"
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.index ["job_post_id"], name: "IDX_job_post_languages_job_post_id"
  end

  create_table "job_post_status_logs", id: { type: :uuid, default: -> { "uuid_generate_v4()" }, comment: "로그 고유 ID" }, comment: "채용 공고 상태 변경 로그", force: :cascade do |t|
    t.timestamptz "changed_at", default: -> { "now()" }, null: false, comment: "변경 일시"
    t.uuid "changed_by", comment: "변경자 ID (null: 시스템)"
    t.integer "changed_by_type"
    t.integer "from_status"
    t.uuid "job_post_id", null: false, comment: "채용 공고 ID"
    t.jsonb "metadata", comment: "추가 메타데이터"
    t.text "reason", comment: "변경 사유"
    t.integer "to_status"
    t.index ["changed_at"], name: "IDX_job_post_status_logs_changed_at"
    t.index ["job_post_id"], name: "IDX_job_post_status_logs_job_post_id"
  end

  create_table "job_posts", id: { type: :uuid, default: -> { "uuid_generate_v4()" }, comment: "채용 공고 고유 ID" }, force: :cascade do |t|
    t.timestamptz "approved_at", comment: "승인 일시"
    t.uuid "approved_by", comment: "승인자 ID"
    t.timestamptz "closed_at", comment: "종료 일시"
    t.jsonb "contract_conditions", comment: "계약 및 근무 조건"
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.timestamptz "deadline", comment: "모집 마감일"
    t.integer "deadline_type"
    t.jsonb "description", null: false, comment: "상세 내용"
    t.integer "employment_type"
    t.integer "experience_level"
    t.boolean "language_required", default: false, null: false, comment: "외국어 능력 필요 여부"
    t.boolean "priority", default: false, null: false, comment: "우선 노출 여부"
    t.integer "publication_type"
    t.timestamptz "published_at", comment: "게시 일시"
    t.jsonb "published_snapshot", comment: "게시된 버전 스냅샷 (수정 중일 때 기존 정보 보관)"
    t.text "rejection_reason", comment: "반려 사유"
    t.integer "request_count", default: 0, null: false, comment: "게시 신청 회차"
    t.timestamptz "scheduled_publish_date", comment: "예약 게시일 (모집 시작일)"
    t.text "skills", comment: "기술 및 역량", array: true
    t.integer "status"
    t.string "title", limit: 255, null: false, comment: "채용 공고명"
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.integer "view_count", default: 0, null: false, comment: "조회수"
    t.uuid "workspace_id", null: false, comment: "워크스페이스 ID (외부 DB 참조)"
    t.index ["employment_type"], name: "index_job_posts_on_employment_type"
    t.index ["published_at"], name: "IDX_job_posts_published_at"
    t.index ["status"], name: "index_job_posts_on_status"
    t.index ["workspace_id"], name: "IDX_job_posts_workspace_id"
  end

  create_table "jobs", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false, comment: "생성 시간"
    t.uuid "job_category_id", null: false, comment: "직군 ID"
    t.string "name", null: false, comment: "직무 이름"
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false, comment: "수정 시간"
    t.index ["job_category_id"], name: "IDX_8bfcd4b06680a050132fcf3408"
    t.index ["name"], name: "IDX_e480da468fa5ef0b9a8f90c438"
  end

  create_table "migrations_history", id: :serial, force: :cascade do |t|
    t.string "name", null: false
    t.bigint "timestamp", null: false
  end

  create_table "practical_strength_references", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false, comment: "생성 시간"
    t.uuid "job_category_id", null: false, comment: "직군 ID"
    t.string "reference", null: false, comment: "실무 강점"
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false, comment: "수정 시간"
    t.index ["job_category_id"], name: "IDX_ebd3ab62e751044a5f540d6613"
    t.index ["reference"], name: "IDX_982453385093f89b70e64d302e"
  end

  create_table "profile_attachments", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false, comment: "생성 시간"
    t.bigint "file_size", comment: "파일 크기 (bytes)"
    t.string "mime_type", limit: 100, comment: "파일 MIME 타입"
    t.string "original_file_name", limit: 255, null: false, comment: "원본 파일명"
    t.uuid "profile_id", null: false, comment: "프로필 ID"
    t.integer "sort_order", default: 0, null: false, comment: "정렬 순서"
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false, comment: "수정 시간"
    t.string "url", limit: 2048, comment: "S3 저장 URL"
    t.index ["profile_id"], name: "IDX_45e021070eaeffc40896e0e127"
  end

  create_table "profile_educations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false, comment: "생성 시간"
    t.string "double_major", comment: "복수전공"
    t.integer "education_level"
    t.date "enrollment_date", comment: "입학일"
    t.date "graduation_date", comment: "졸업일"
    t.string "major", null: false, comment: "전공"
    t.string "minor", comment: "부전공"
    t.uuid "profile_id", null: false, comment: "프로필 ID"
    t.string "school", null: false, comment: "학교"
    t.integer "status"
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false, comment: "수정 시간"
    t.index ["profile_id"], name: "IDX_fc20c4e25b5e90c16247d1a84c"
  end

  create_table "profile_experiences", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "company", null: false, comment: "회사명"
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false, comment: "생성 시간"
    t.boolean "current", default: false, null: false, comment: "현재 재직 중 여부"
    t.date "end_date", comment: "퇴사일"
    t.boolean "is_featured", default: false, null: false, comment: "대표 경력 여부"
    t.string "position", null: false, comment: "직무"
    t.uuid "profile_id", null: false, comment: "프로필 ID"
    t.date "start_date", null: false, comment: "입사일"
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false, comment: "수정 시간"
    t.integer "work_type"
    t.index ["profile_id"], name: "IDX_748cbfc317f4e84d1bf6557c21"
  end

  create_table "profile_freelance_experiences", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "company", null: false, comment: "회사"
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false, comment: "생성 시간"
    t.uuid "profile_id", null: false, comment: "프로필 ID"
    t.date "project_end_date", comment: "프로젝트 종료일"
    t.string "project_name", null: false, comment: "프로젝트명"
    t.date "project_start_date", null: false, comment: "프로젝트 시작일"
    t.boolean "recurring_contract", default: false, null: false, comment: "반복 계약 여부"
    t.text "role_and_contribution", null: false, comment: "역할 및 기여 포인트"
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false, comment: "수정 시간"
    t.integer "weekly_hours", comment: "주당 근무시간 (파트타임인 경우)"
    t.integer "work_type"
    t.string "working_hours", default: "fullTime", null: false, comment: "근무 시간 (fullTime/partTime)"
    t.index ["profile_id"], name: "IDX_e00f4ef0adfbc3f397d4ad2670"
  end

  create_table "profile_highlights", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "action", comment: "Action 기여 내용 (deprecated)"
    t.text "after", null: false, comment: "After 성과"
    t.string "before", comment: "Before 과제 (deprecated)"
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false, comment: "생성 시간"
    t.text "details", null: false, comment: "상세내용"
    t.uuid "profile_id", null: false, comment: "프로필 ID"
    t.string "title", comment: "제목"
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false, comment: "수정 시간"
    t.index ["profile_id"], name: "IDX_6224687411d1eaa98e6e96677d"
  end

  create_table "profile_jobs", primary_key: ["profile_id", "job_id"], force: :cascade do |t|
    t.uuid "job_id", null: false
    t.uuid "profile_id", null: false
    t.index ["job_id"], name: "IDX_e9b1212b37eacf375525c60ec3"
    t.index ["profile_id"], name: "IDX_f01e5084aed7ef326f9639a12d"
  end

  create_table "profile_languages", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false, comment: "생성 시간"
    t.string "language", null: false, comment: "언어"
    t.integer "proficiency"
    t.uuid "profile_id", null: false, comment: "프로필 ID"
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false, comment: "수정 시간"
    t.index ["profile_id"], name: "IDX_df6358f1f8423f535d30ad5727"
  end

  create_table "profile_links", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false, comment: "생성 시간"
    t.uuid "profile_id", null: false, comment: "프로필 ID"
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false, comment: "수정 시간"
    t.string "url", limit: 2048, null: false, comment: "링크 URL"
    t.index ["profile_id"], name: "IDX_bb4b1e7c4357bbd0a3220410c7"
  end

  create_table "profile_projects", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "background_or_goal", null: false, comment: "배경 또는 목표"
    t.string "company", null: false, comment: "회사"
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false, comment: "생성 시간"
    t.uuid "profile_id", null: false, comment: "프로필 ID"
    t.date "project_end_date", comment: "프로젝트 종료일"
    t.string "project_name", null: false, comment: "프로젝트명"
    t.date "project_start_date", null: false, comment: "프로젝트 시작일"
    t.text "result", null: false, comment: "결과"
    t.string "role", null: false, comment: "역할"
    t.string "tools", null: false, comment: "사용툴"
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false, comment: "수정 시간"
    t.integer "weekly_hours", comment: "주당 근무시간 (파트타임인 경우)"
    t.string "working_hours", default: "fullTime", null: false, comment: "근무 시간 (fullTime/partTime)"
    t.index ["profile_id"], name: "IDX_27b0e1fbdc01ae8df9f81d1c1e"
  end

  create_table "profiles", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "about", comment: "상세 소개"
    t.string "collaboration_and_communication", comment: "협업과 소통 강점"
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false, comment: "생성 시간"
    t.string "domicile", comment: "거주지"
    t.boolean "email_public", default: false, null: false, comment: "이메일 공개 여부"
    t.jsonb "employment_type", comment: "고용 형태"
    t.string "expertise", comment: "전문 분야"
    t.string "introduction", comment: "한 줄 소개"
    t.uuid "job_category_id", comment: "직군 ID"
    t.integer "job_seeking_status"
    t.string "name", limit: 100, comment: "사용자 이름"
    t.uuid "nationality_id", comment: "국적 ID"
    t.integer "overall_completeness", default: 0, null: false, comment: "전체 완성도 (0-100)"
    t.string "phone", comment: "전화번호"
    t.string "practical_strength", comment: "실무 강점"
    t.string "problem_solving_and_execution", comment: "문제 해결과 실행력"
    t.string "profile_image", comment: "프로필 사진 URL"
    t.integer "required_completeness", default: 0, null: false, comment: "필수 완성도 (0-100)"
    t.text "skills", comment: "기술 및 역량", array: true
    t.integer "start_work"
    t.decimal "total_years_of_experience", precision: 4, scale: 1, default: "0.0", null: false, comment: "총 경력 연수 (년 단위)"
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false, comment: "수정 시간"
    t.uuid "user_id", null: false, comment: "사용자 ID"
    t.integer "weight", default: 0, null: false, comment: "프로필 가중치 (정렬용)"
    t.text "work_type", comment: "근무 형태", array: true
    t.index ["job_seeking_status"], name: "index_profiles_on_job_seeking_status"
    t.index ["overall_completeness"], name: "IDX_profiles_overallCompleteness", order: :desc
    t.index ["required_completeness"], name: "IDX_profiles_requiredCompleteness", order: :desc
    t.index ["total_years_of_experience"], name: "IDX_profiles_totalYearsOfExperience", order: :desc
    t.index ["user_id"], name: "IDX_315ecd98bd1a42dcf2ec4e2e98", unique: true
    t.index ["weight"], name: "IDX_profiles_weight", order: :desc
  end

  create_table "query-result-cache", id: :serial, force: :cascade do |t|
    t.integer "duration", null: false
    t.string "identifier"
    t.text "query", null: false
    t.text "result", null: false
    t.bigint "time", null: false
  end

  create_table "recommendation_notification_history", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false
    t.uuid "job_post_id"
    t.string "recipient_email", limit: 255, null: false
    t.uuid "recipient_id", null: false
    t.uuid "sender_id", null: false
    t.datetime "sent_at", precision: nil, default: -> { "now()" }, null: false
    t.string "type", limit: 50, null: false
    t.index ["job_post_id"], name: "IDX_rec_history_job_post", where: "(job_post_id IS NOT NULL)"
    t.index ["sent_at"], name: "IDX_rec_history_sent_at"
    t.index ["type", "recipient_id", "sender_id"], name: "IDX_rec_history_lookup"
  end

  create_table "recruitment_requests", force: :cascade do |t|
    t.string "company_name", null: false
    t.string "contact_name", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.text "message", null: false
    t.string "phone", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_recruitment_requests_on_created_at"
    t.index ["email"], name: "index_recruitment_requests_on_email"
    t.index ["status"], name: "index_recruitment_requests_on_status"
  end

  create_table "typeorm_metadata", id: false, force: :cascade do |t|
    t.string "database"
    t.string "name"
    t.string "schema"
    t.string "table"
    t.string "type", null: false
    t.text "value"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "application_context_references", "job_categories", name: "FK_6e168fbb59ea943d45a621ea2e9"
  add_foreign_key "blog_category", "blog_category", column: "parent_id", name: "fk_blog_category_parent", on_delete: :nullify
  add_foreign_key "blog_post_category", "blog_category", column: "category_id", name: "fk_blog_post_category_category", on_delete: :cascade
  add_foreign_key "blog_post_category", "blog_post", name: "fk_blog_post_category_post", on_delete: :cascade
  add_foreign_key "blog_view", "blog_post", name: "fk_blog_view_post", on_delete: :cascade
  add_foreign_key "career_hub_categories", "career_hub_categories", column: "parent_id", name: "FK_career_hub_categories_parent", on_delete: :nullify
  add_foreign_key "career_hub_communities", "career_hub_categories", column: "category_id", name: "FK_career_hub_communities_category", on_delete: :nullify
  add_foreign_key "career_hub_communities", "career_hub_categories", column: "subcategory_id", name: "FK_career_hub_communities_subcategory", on_delete: :nullify
  add_foreign_key "career_hub_communities", "career_hub_community_leaders", column: "leader_id", name: "FK_career_hub_communities_leader", on_delete: :nullify
  add_foreign_key "career_hub_community_event_participants", "career_hub_community_events", column: "event_id", name: "FK_career_hub_event_participants_event", on_delete: :cascade
  add_foreign_key "career_hub_community_events", "career_hub_communities", column: "community_id", name: "FK_career_hub_community_events_community", on_delete: :cascade
  add_foreign_key "career_hub_community_feed_likes", "career_hub_community_feeds", column: "feed_id", name: "FK_career_hub_likes_feed", on_delete: :cascade
  add_foreign_key "career_hub_community_feeds", "career_hub_communities", column: "community_id", name: "FK_career_hub_feeds_community", on_delete: :cascade
  add_foreign_key "career_hub_community_feeds", "career_hub_community_feeds", column: "parent_id", name: "FK_career_hub_feeds_parent", on_delete: :cascade
  add_foreign_key "career_hub_community_feeds", "career_hub_community_feeds", column: "root_id", name: "FK_career_hub_feeds_root", on_delete: :cascade
  add_foreign_key "career_hub_community_members", "career_hub_communities", column: "community_id", name: "FK_career_hub_community_members_community", on_delete: :cascade
  add_foreign_key "career_hub_event_reviews", "career_hub_community_events", column: "event_id", name: "FK_career_hub_event_reviews_event", on_delete: :cascade
  add_foreign_key "featured_profiles", "profiles", name: "FK_a2eae56d3d6401ca3443973ada3"
  add_foreign_key "highlight_references", "job_categories", name: "FK_2802b70c3add45cacf70280538e"
  add_foreign_key "job_applications", "job_posts", name: "FK_job_applications_job_post", on_delete: :cascade
  add_foreign_key "job_applications", "profiles", name: "FK_job_applications_profile", on_delete: :cascade
  add_foreign_key "job_post_categories", "job_categories", name: "FK_job_post_categories_job_category", on_update: :cascade, on_delete: :cascade
  add_foreign_key "job_post_categories", "job_posts", name: "FK_job_post_categories_job_post", on_update: :cascade, on_delete: :cascade
  add_foreign_key "job_post_jobs", "job_posts", name: "FK_job_post_jobs_job_post", on_update: :cascade, on_delete: :cascade
  add_foreign_key "job_post_jobs", "jobs", name: "FK_job_post_jobs_job", on_update: :cascade, on_delete: :cascade
  add_foreign_key "job_post_languages", "job_posts", name: "FK_job_post_languages_job_post", on_delete: :cascade
  add_foreign_key "job_post_status_logs", "job_posts", name: "FK_job_post_status_logs_job_post", on_delete: :cascade
  add_foreign_key "jobs", "job_categories", name: "FK_8bfcd4b06680a050132fcf3408a"
  add_foreign_key "practical_strength_references", "job_categories", name: "FK_ebd3ab62e751044a5f540d6613f"
  add_foreign_key "profile_attachments", "profiles", name: "FK_45e021070eaeffc40896e0e127b", on_delete: :cascade
  add_foreign_key "profile_educations", "profiles", name: "FK_fc20c4e25b5e90c16247d1a84c7", on_delete: :cascade
  add_foreign_key "profile_experiences", "profiles", name: "FK_748cbfc317f4e84d1bf6557c21b", on_delete: :cascade
  add_foreign_key "profile_freelance_experiences", "profiles", name: "FK_e00f4ef0adfbc3f397d4ad2670e", on_delete: :cascade
  add_foreign_key "profile_highlights", "profiles", name: "FK_6224687411d1eaa98e6e96677d1", on_delete: :cascade
  add_foreign_key "profile_jobs", "jobs", name: "FK_e9b1212b37eacf375525c60ec37"
  add_foreign_key "profile_jobs", "profiles", name: "FK_f01e5084aed7ef326f9639a12d4", on_update: :cascade, on_delete: :cascade
  add_foreign_key "profile_languages", "profiles", name: "FK_df6358f1f8423f535d30ad57271", on_delete: :cascade
  add_foreign_key "profile_links", "profiles", name: "FK_bb4b1e7c4357bbd0a3220410c77", on_delete: :cascade
  add_foreign_key "profile_projects", "profiles", name: "FK_27b0e1fbdc01ae8df9f81d1c1ea", on_delete: :cascade
  add_foreign_key "profiles", "countries", column: "nationality_id", name: "FK_1c65de5f281abc4009f47f07121"
  add_foreign_key "profiles", "job_categories", name: "FK_f6a45621540df52df1891907d73"
end
