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

ActiveRecord::Schema[8.0].define(version: 2025_04_02_210741) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "episodes", force: :cascade do |t|
    t.integer "number"
    t.string "title"
    t.string "video_id"
    t.date "air_date"
    t.text "notes"
    t.string "thumbnail_url"
    t.integer "duration_seconds"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "summary"
    t.index ["number"], name: "index_episodes_on_number", unique: true
    t.index ["video_id"], name: "index_episodes_on_video_id", unique: true
  end

  create_table "guest_messages", force: :cascade do |t|
    t.string "sender_name"
    t.string "sender_email"
    t.text "message"
    t.integer "profile_id"
    t.string "status", default: "new"
    t.text "admin_notes"
    t.datetime "forwarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "subject"
    t.string "location"
    t.string "practice_size"
    t.string "specialty"
    t.boolean "is_podcast_application", default: false
    t.index ["profile_id"], name: "index_guest_messages_on_profile_id"
  end

  create_table "profile_episodes", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.integer "episode_id", null: false
    t.string "appearance_type"
    t.text "notes"
    t.boolean "is_primary_guest", default: false
    t.string "segment_title"
    t.integer "segment_start_time"
    t.integer "segment_end_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["episode_id"], name: "index_profile_episodes_on_episode_id"
    t.index ["profile_id", "episode_id"], name: "idx_profile_episodes", unique: true
    t.index ["profile_id"], name: "index_profile_episodes_on_profile_id"
  end

  create_table "profile_specializations", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.integer "specialization_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id", "specialization_id"], name: "idx_profiles_specializations", unique: true
    t.index ["profile_id"], name: "index_profile_specializations_on_profile_id"
    t.index ["specialization_id"], name: "index_profile_specializations_on_specialization_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.string "name"
    t.string "headline"
    t.text "bio"
    t.string "location"
    t.string "specializations"
    t.string "linkedin_url"
    t.string "youtube_url"
    t.string "email"
    t.string "phone"
    t.string "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "company"
    t.string "website"
    t.string "mailing_address"
    t.string "facebook_url"
    t.string "twitter_url"
    t.string "instagram_url"
    t.string "tiktok_url"
    t.text "testimonial"
    t.string "headshot_url"
    t.boolean "interested_in_procurement", default: false
    t.date "submission_date"
    t.integer "deprecated_episode_number"
    t.string "deprecated_episode_title"
    t.string "deprecated_episode_url"
    t.date "deprecated_episode_date"
    t.float "latitude"
    t.float "longitude"
    t.string "cached_formatted_location"
    t.string "cached_city"
    t.string "cached_country"
    t.boolean "allow_messages", default: true
    t.string "message_forwarding_email"
    t.boolean "auto_forward_messages", default: false
    t.string "status", default: "guest"
    t.string "practice_size"
    t.text "podcast_objectives"
    t.boolean "partner", default: false
    t.index ["partner"], name: "index_profiles_on_partner"
    t.index ["status"], name: "index_profiles_on_status"
  end

  create_table "specializations", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "youtube_sync_histories", force: :cascade do |t|
    t.string "channel_id"
    t.datetime "last_synced_at"
    t.integer "videos_processed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "guest_messages", "profiles"
  add_foreign_key "profile_episodes", "episodes"
  add_foreign_key "profile_episodes", "profiles"
  add_foreign_key "profile_specializations", "profiles"
  add_foreign_key "profile_specializations", "specializations"
end
