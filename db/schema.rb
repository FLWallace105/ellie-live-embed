# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20171025193112) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "customer_alt_product", force: :cascade do |t|
    t.string "shopify_id"
    t.string "subscription_id"
    t.string "alt_product_id"
    t.string "alt_variant_id"
    t.string "alt_product_title"
    t.datetime "date_switched"
    t.index ["shopify_id"], name: "index_customer_alt_product_on_shopify_id"
    t.index ["subscription_id"], name: "index_customer_alt_product_on_subscription_id"
  end

  create_table "customer_skips", force: :cascade do |t|
    t.string "shopify_id"
    t.string "subscription_id"
    t.datetime "skipped_on"
    t.string "skip_reason"
    t.boolean "skip_status"
    t.string "charge_id"
    t.datetime "skipped_to"
    t.index ["shopify_id"], name: "index_customer_skips_on_shopify_id"
    t.index ["subscription_id"], name: "index_customer_skips_on_subscription_id"
  end

  create_table "influencers", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "address1"
    t.string "address2"
    t.string "city"
    t.string "state"
    t.string "zip"
    t.string "email"
    t.string "phone"
    t.string "bra_size"
    t.string "top_size"
    t.string "bottom_size"
    t.boolean "three_item"
    t.boolean "processed"
    t.datetime "time_order_submitted"
    t.string "sports_jacket_size"
  end

  create_table "tickets", force: :cascade do |t|
    t.string "influencer_code"
    t.boolean "code_used", default: false
    t.index ["influencer_code"], name: "index_tickets_on_influencer_code", unique: true
  end

end
