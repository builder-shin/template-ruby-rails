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

ActiveRecord::Schema[8.1].define(version: 2026_02_05_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "example_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_example_categories_on_name", unique: true
  end

  create_table "example_taggings", primary_key: ["example_id", "tag_id"], force: :cascade do |t|
    t.uuid "example_id", null: false
    t.uuid "tag_id", null: false
  end

  create_table "example_tags", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_example_tags_on_name", unique: true
  end

  create_table "examples", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "category_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "score", default: 0, null: false
    t.string "status", default: "draft", null: false
    t.string "title", limit: 200, null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_examples_on_category_id"
    t.check_constraint "score >= 0 AND score <= 100", name: "examples_score_check"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'active'::character varying::text, 'archived'::character varying::text])", name: "examples_status_check"
  end

  create_table "refresh_sessions", id: :uuid, default: nil, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.uuid "replaced_by_id"
    t.datetime "revoked_at"
    t.string "token_hash", limit: 64, null: false
    t.uuid "user_id", null: false
    t.index ["expires_at"], name: "index_refresh_sessions_on_expires_at"
    t.index ["replaced_by_id"], name: "index_refresh_sessions_on_replaced_by_id"
    t.index ["token_hash"], name: "index_refresh_sessions_on_token_hash", unique: true
    t.index ["user_id"], name: "index_refresh_sessions_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", limit: 254, null: false
    t.boolean "is_active", default: true, null: false
    t.text "password_hash", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "example_taggings", "example_tags", column: "tag_id", on_delete: :cascade
  add_foreign_key "example_taggings", "examples", on_delete: :cascade
  add_foreign_key "examples", "example_categories", column: "category_id", on_delete: :nullify
  add_foreign_key "refresh_sessions", "refresh_sessions", column: "replaced_by_id", on_delete: :nullify
  add_foreign_key "refresh_sessions", "users", on_delete: :cascade
end
