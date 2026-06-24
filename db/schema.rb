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

ActiveRecord::Schema[8.1].define(version: 2026_02_04_100001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "blog_category", "blog_category", column: "parent_id", name: "fk_blog_category_parent", on_delete: :nullify
  add_foreign_key "blog_post_category", "blog_category", column: "category_id", name: "fk_blog_post_category_category", on_delete: :cascade
  add_foreign_key "blog_post_category", "blog_post", name: "fk_blog_post_category_post", on_delete: :cascade
  add_foreign_key "blog_view", "blog_post", name: "fk_blog_view_post", on_delete: :cascade
end
