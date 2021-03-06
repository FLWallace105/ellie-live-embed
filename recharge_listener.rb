#recharge_listener.rb
require 'sinatra/base'
require 'json'
require 'httparty'
require 'dotenv'
require "resque"
require 'shopify_api'
require 'active_support/core_ext'
require 'sinatra/activerecord'

require './models/model'

require_relative 'worker_helpers'

class SkipIt < Sinatra::Base
  register Sinatra::ActiveRecordExtension

configure do

  enable :logging
  set :server, :puma
  Dotenv.load
  #set :protection, :except => [:json_csrf]
  
  
  mime_type :application_javascript, 'application/javascript'
  mime_type :application_json, 'application/json'
  #$recharge_access_token = ENV['RECHARGE_ACCESS_TOKEN']
  $recharge_access_token = ENV['RECHARGE_STAGING_ACCESS_TOKEN']
  $my_get_header =  {
            "X-Recharge-Access-Token" => "#{$recharge_access_token}"
        }
  $my_change_charge_header = {
            "X-Recharge-Access-Token" => "#{$recharge_access_token}",
            "Accept" => "application/json",
            "Content-Type" =>"application/json"
        }

  #uncomment below for push to Heroku.
  uri2 = URI.parse(ENV["REDIS_URL"])
  REDIS = Redis.new(:host => uri2.host, :port => uri2.port, :password => uri2.password)

  #SHOPIFY env variables
  $apikey = ENV['ELLIE_STAGING_API_KEY']
  $password = ENV['ELLIE_STAGING_PASSWORD']
  $shopname = ENV['SHOPNAME']
  $shopify_wait = ENV['SHOPIFY_SLEEP_TIME']
  $recharge_wait = ENV['RECHARGE_SLEEP_TIME']
  SHOP_WAIT = ENV['SHOPIFY_SLEEP_TIME']
  RECH_WAIT = ENV['RECHARGE_SLEEP_TIME']
  PROD_ID = ENV['INFLUENCER_PRODUCT_ID']
  NEW_CUST_TAGS = ENV['NEW_CUST_TAGS']
  INFLUENCER_TAG = ENV['INFLUENCER_TAG']
  INFLUENCER_ORDER = ENV['INFLUENCER_ORDER']
  INFLUENCER_PRODUCT = ENV['INFLUENCER_PRODUCT']
  INFLUENCER_BOTTLE = ENV['INFLUENCER_BOTTLE']
  INFLUENCER_BOTTLE_ID = ENV['INFLUENCER_BOTTLE_ID']
  BOTTLE_SKU = ENV['BOTTLE_SKU']
  BOX_SKU = ENV['BOX_SKU']
  SHOPIFY_THREE_MONTHS = ENV['SHOPIFY_THREE_MONTHS']
  CUST_TAG_THREE_MONTHS = ENV['CUST_TAG_THREE_MONTHS']
  SHOPIFY_MONTHLY_BOX_ID = ENV['SHOPIFY_MONTHLY_BOX_ID']
  SHOPIFY_ELLIE_3PACK_ID = ENV['SHOPIFY_ELLIE_3PACK_ID']
  SHOPIFY_3MONTH_ID = ENV['SHOPIFY_3MONTH_ID']
  SHOPIFY_MONTHLY_BOX_AUTORENEW_ID = ENV['SHOPIFY_MONTHLY_BOX_AUTORENEW_ID']

end



def initialize
    #Dotenv.load
    @key = ENV['SHOPIFY_API_KEY']
    @secret = ENV['SHOPIFY_SHARED_SECRET'] 
    @app_url = "ellie-live-embed.herokuapp.com"
    @tokens = {}
    @uri = URI.parse(ENV['DATABASE_URL'])
    @monthly_box_id = ENV['SHOPIFY_MONTHLY_BOX_ID']
    @ellie_threepack_id = ENV['SHOPIFY_ELLIE_3PACK_ID']
    
    @alt_monthly_box_sku = ENV['ALT_MONTHLY_BOX_SKU']
    @alt_monthly_box_title = ENV['ALT_MONTHLY_BOX_TITLE']
    @alt_monthly_box_id = ENV['ALT_MONTHLY_BOX_ID']
    @alt_monthly_box_variant_id = ENV['ALT_MONTHLY_BOX_VARIANT_ID']
    @alt_ellie_3pack_id = ENV['ALT_ELLIE_3PACK_ID']
    @alt_ellie_3pack_sku = ENV['ALT_ELLIE_3PACK_SKU']
    @alt_ellie_3pack_title = ENV['ALT_ELLIE_3PACK_TITLE']
    @alt_ellie_3pack_variant_id = ENV['ALT_ELLIE_3PACK_VARIANT_ID']

    super
  end

  get '/install' do
  shop = "ellieactive.myshopify.com"
  scopes = "read_orders, write_orders, read_products, read_customers, write_customers"

  # construct the installation URL and redirect the merchant
  install_url =
    "http://#{shop}/admin/oauth/authorize?client_id=#{@key}&scope=#{scopes}"\
    "&redirect_uri=http://#{@app_url}/auth/shopify/callback"

  redirect install_url
end

get '/auth/shopify/callback' do
  # extract shop data from request parameters
  shop = request.params['shop']
  code = request.params['code']
  hmac = request.params['hmac']

  # perform hmac validation to determine if the request is coming from Shopify
  h = request.params.reject{|k,_| k == 'hmac' || k == 'signature'}
  query = URI.escape(h.sort.collect{|k,v| "#{k}=#{v}"}.join('&'))
  digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), @secret, query)

  if not (hmac == digest)
    return [403, "Authentication failed. Digest provided was: #{digest}"]
  end

  # if we don't have an access token for this particular shop,
    # we'll post the OAuth request and receive the token in the response
    if @tokens[shop].nil?
      url = "https://#{shop}/admin/oauth/access_token"

      payload = {
        client_id: @key,
        client_secret: @secret,
        code: code}

      response = HTTParty.post(url, body: payload)

      # if the response is successful, obtain the token and store it in a hash
      if response.code == 200
        @tokens[shop] = response['access_token']
      else
        return [500, "Something went wrong."]
      end
    end

    # now that we have the token, we can instantiate a session
    session = ShopifyAPI::Session.new(shop, @tokens[shop])
    @my_session = session
    ShopifyAPI::Base.activate_session(session)

    # create webhook for order creation if it doesn't exist
    

    
    redirect '/hello'

end

get '/hello' do
  "Hello, success, thanks for installing me!"
end

post '/alt_cust_skip' do
  status 200
  puts "Doing the alternate customer skip after they declined alternate product this month"
  params['uri'] = @uri
  params['monthly_box_id'] = @monthly_box_id
  params['ellie_threepack_id'] = @ellie_threepack_id
  puts params.inspect
  my_now_date = Date.today
  my_now_date_int = my_now_date.day
  if my_now_date_int < 5
    Resque.enqueue(AltSkip, params)
  else
    puts "Today is #{my_now_date.inspect}"
    puts "We cannot skip, it is #{my_now_date_int} which is later than the 4th of the month"
  end

end

post '/alt_product_choose' do
  status 200
  puts "Doing the switch customer this month to the alternate product this month"
  params['uri'] = @uri
  params['monthly_box_id'] = @monthly_box_id
  params['ellie_threepack_id'] = @ellie_threepack_id
  params['alt_monthly_box_sku'] = @alt_monthly_box_sku
  params['alt_monthly_box_title'] = @alt_monthly_box_title
  params['alt_monthly_box_id'] = @alt_monthly_box_id
  params['alt_monthly_box_variant_id'] = @alt_monthly_box_variant_id
  params['alt_ellie_3pack_id'] = @alt_ellie_3pack_id
  params['alt_ellie_3pack_sku'] = @alt_ellie_3pack_sku
  params['alt_ellie_3pack_title'] = @alt_ellie_3pack_title
  params['alt_ellie_3pack_variant_id'] = @alt_ellie_3pack_variant_id
  
  puts params.inspect
  Resque.enqueue(AltChoose, params)

end 

post '/funky-next-month-preview' do
  content_type :application_javascript
  #response.headers['Access-Control-Allow-Origin'] = 'http://example.com'
  status 200
  puts "Doing Funky Skip Next Month Preview"
  puts params.inspect
 

end


post '/subscription_created' do
  content_type :application_javascript
  status 200
  puts "Received new subscriptions"
  puts params.inspect
  mystuff = JSON.parse(request.body.read)
  puts mystuff.inspect
  Resque.enqueue(SubscriptionListener, mystuff)
end


post '/subscription_deleted' do
  content_type :application_javascript
  status 200
  puts "Received a deleted subscription"
  puts params.inspect
  mystuff = JSON.parse(request.body.read)
  puts mystuff.inspect
  Resque.enqueue(SubscriptionDeleted, mystuff)


end


post '/influencer-bottle' do
  content_type :application_javascript
  status 200
  puts "Processing Influencer BOTTLE Request"
  puts params.inspect
  Resque.enqueue(InfluencerBottle, params)
end

post '/influencer-box' do
  content_type :application_javascript
  status 200
  puts "Processing Influencer Order"
  puts params.inspect
  Resque.enqueue(InfluencerBox, params)
end

post '/restart-customer' do
  content_type :application_javascript
  status 200
  puts "Restarting Customer through Recharge API"
  puts params.inspect
  Resque.enqueue(ReactivateCustomer, params)

end

post '/next-month-skip' do
  content_type :application_javascript
  status 200
  puts "Doing Skip Next Month Preview"
  puts params.inspect
  Resque.enqueue(SkipPreviewMonth, params)

end

post '/preview-upsells' do
  content_type :application_javascript
  status 200
  puts "Doing Preview Month Upsell"
  puts params.inspect
  
  Resque.enqueue(UpsellPreviewMonth, params)


end



post '/recharge' do
  content_type :application_javascript
  status 200
  puts "doing GET stuff"
  puts params.inspect
  shopify_id = params['shopify_id']
  puts shopify_id
  action = params['action']

  #stuff below for Heroku
  Resque.redis = REDIS
  skip_month_data = {'shopify_id' => shopify_id, 'action' => action}
  Resque.enqueue(SkipMonth, skip_month_data)


end

post '/next-month-preview' do
  content_type content_type :application_javascript
  
  shopify_id = params['shopify_id']
  new_date = params['new_date']
  action = params['action']
  #customer_data = {"new_date" => new_date}
  #customer_data = customer_data.to_json
  #send_back = "previewDate(#{customer_data});"
  #body send_back
  #puts send_back

  #status 200
  puts "Processing Next Month Preview Ship Request"
  puts params.inspect
  preview_month_data = {"shopify_id" => shopify_id, "ship_date" => new_date, "action" => action}
  Resque.redis = REDIS
  Resque.enqueue(PreviewMonth, preview_month_data)
end

post '/recharge-new-ship-date' do
  content_type :application_javascript
  status 200

  puts "Doing change ship date"
  puts params.inspect
  shopify_id = params['shopify_id']
  new_date = params['new_date']
  action = params['action']
  choosedate_data = {"shopify_id" => shopify_id, "new_date" => new_date, 'action' => action}

  #stuff below for Heroku
  Resque.redis = REDIS
  Resque.enqueue(ChooseDate, choosedate_data)

end

get '/recharge-unskip' do
  content_type :application_javascript
  status 200

  puts "Doing unskipping task"
  puts params.inspect
  shopify_id = params['shopify_id']
  action = params['action']

  unskip_data = {"shopify_id" => shopify_id, "action" => action }

  #stuff below for Heroku
  Resque.redis = REDIS
  Resque.enqueue(UnSkip, unskip_data)

end

get '/customer_size_returner' do
  content_type :application_json
  puts params.inspect
  action = params['action']
  shopify_id = params['shopify_id']
  puts "Shopify_id = #{shopify_id} and action = #{action}"
  sleep 6

  my_data = {"shopify_id" => shopify_id, "action" => action}
  customer_data = return_cust_sizes(my_data)
  puts customer_data.inspect
  customer_data = customer_data.to_json
  send_back = "custSize(#{customer_data})"
  body send_back
  puts send_back

  puts "Done now"

end

post '/upsells' do
  puts "Doing upsell task"
  puts params.inspect


  content_type :application_json
  customer_data = {"return_value" => "hi_there"}
  customer_data = customer_data.to_json
  send_back = "myUpsells(#{customer_data})"
  body send_back
  puts send_back
  #stuff below for Heroku
  Resque.redis = REDIS
  Resque.enqueue(UpsellProcess, params)

end

post '/upsell_remove' do
  puts "Doing removing Upsell products from box subscription"
  puts params.inspect
  content_type :application_json
  customer_data = {"return_value" => "yeah_ok_removing_dude"}
  customer_data = customer_data.to_json
  send_back = "myUpsellsRemove(#{customer_data})"
  body send_back
  puts send_back

  Resque.redis = REDIS
  Resque.enqueue(UpsellRemove, params)


end


post '/change_cust_size' do
  puts "Doing changing customer sizes"
  puts params.inspect
  #stuff below for Heroku
  Resque.redis = REDIS
  Resque.enqueue(ChangeCustSizes, params)

end



helpers do

  def return_cust_sizes(my_data)
    #first check to make sure it is correct action
    action = my_data['action']
    shopify_id = my_data['shopify_id']
    current_month = Date.today.strftime("%B")
    alt_title = "#{current_month} VIP Box"
    # --------- define customer size variables and instantiate the customer size array
    leggings_size = ''
    bra_size = ''
    tops_size = ''
    customer_sizes = {}
    orig_sub_date = ''
    # ----------------
    if action == 'need_cust_sizes'
      puts "Getting Customer Sizes"
      my_subscription_id = ''
      orig_sub_date = ''
      get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => $my_get_header)
      subscriber_info = get_sub_info.parsed_response
      #puts subscriber_info.inspect
      subscriptions = get_sub_info.parsed_response['subscriptions']
      puts subscriptions.inspect
      subscriptions.each do |subs|
        puts subs.inspect
        if subs['product_title'] == "Monthly Box" || subs['product_title'] == alt_title
          #puts "Subscription scheduled at: #{subs['next_charge_scheduled_at']}"
          orig_sub_date = subs['next_charge_scheduled_at']
          my_subscription_id = subs['id']
          sizes_stuff = subs['properties']
          puts sizes_stuff.inspect
          sizes_stuff.each do |stuff|
            puts stuff.inspect
              case stuff['name']
                when 'leggings'
                    leggings_size = stuff['value']
                when 'sports-bra'
                    bra_size = stuff['value']
                when 'tops'
                    tops_size = stuff['value']
              end #case

            end

          end
        end
      #set customer sizes
      customer_sizes = {"leggings" => leggings_size, "bra_size" => bra_size, "tops_size" => tops_size}
      my_subscriber_data = {'next_charge_date' => orig_sub_date, 'cust_size_data' => customer_sizes }
      puts my_subscriber_data.inspect
      return my_subscriber_data

    else
      puts "Wrong action, action #{action} is not need_cust_sizes"
      puts "cant do anything"
    end

  end


  def get_subs_date(shopify_id)
    #Get alt_title
    current_month = Date.today.strftime("%B")
    alt_title = "#{current_month} VIP Box"
    orig_sub_date = ""

    get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => $my_get_header)
    subscriber_info = get_sub_info.parsed_response
    #puts subscriber_info.inspect
    subscriptions = get_sub_info.parsed_response['subscriptions']
    puts subscriptions.inspect
    subscriptions.each do |subs|
      puts subs.inspect
      if subs['product_title'] == "Monthly Box" || subs['product_title'] == alt_title
         puts "Subscription scheduled at: #{subs['next_charge_scheduled_at']}"

         end
     end
     orig_sub_date ="\"#{orig_sub_date}\""

  end

end

class AltChoose
  extend FixMonth
  @queue = "alt_choose"
  def self.perform(params)
    puts "Got params --> #{params.inspect}"
    action = params['action']
    uri = params['uri']
    shopify_id = params['shopify_id']
    monthly_box_id = params['monthly_box_id']
    ellie_threepack_id = params['ellie_threepack_id']
    my_id_hash = {"monthly_box_id" => monthly_box_id, "ellie_threepack_id" => ellie_threepack_id }

    alt_monthly_box_sku = params['alt_monthly_box_sku']
    alt_monthly_box_title = params['alt_monthly_box_title']
    alt_monthly_box_id = params['alt_monthly_box_id']
    alt_monthly_box_variant_id = params['alt_monthly_box_variant_id']
    alt_ellie_3pack_id = params['alt_ellie_3pack_id']
    alt_ellie_3pack_sku = params['alt_ellie_3pack_sku']
    alt_ellie_3pack_title = params['alt_ellie_3pack_title']
    alt_ellie_3pack_variant_id = params['alt_ellie_3pack_variant_id']
    my_alt_prod_hash = {"alt_monthly_box_sku" => alt_monthly_box_sku, "alt_monthly_box_title" => alt_monthly_box_title, "alt_monthly_box_id" => alt_monthly_box_id, "alt_monthly_box_variant_id" => alt_monthly_box_variant_id, "alt_ellie_3pack_id" => alt_ellie_3pack_id, "alt_ellie_3pack_sku" => alt_ellie_3pack_sku, "alt_ellie_3pack_title" => alt_ellie_3pack_title, "alt_ellie_3pack_variant_id" => alt_ellie_3pack_variant_id}

    
    unless action == "alternate_collection"
      puts "We cannot do anything, action must alternate_collection not #{action}"
    else
      puts "Choosing alternate product for customer this month"
      get_customer_subscriptions(shopify_id, $my_get_header, $my_change_charge_header, uri, my_id_hash, my_alt_prod_hash)
    end

  end
end

class AltSkip
  extend FixMonth
  @queue = "alt_skip"
  def self.perform(params)
    #puts "Got params"
    puts "received params #{params.inspect}"
    shopify_customer_id = params['shopify_id']
    action = params['action']
    uri = params['uri']
    reason = params['reason']
    monthly_box_id = params['monthly_box_id']
    ellie_threepack_id = params['ellie_threepack_id']
    unless action == 'skip_month'
      puts "We cannot do anything, action must be skip_month not #{action}"
    else
      puts "skipping the month for customer #{shopify_customer_id}"
      
      get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_customer_id}", :headers => $my_get_header)
      #puts get_sub_info.inspect
      my_sub_array = Array.new
      check_recharge_limits(get_sub_info)
      mysub = get_sub_info.parsed_response['subscriptions']
      mysub.each do |subs|
        
        #puts subs.inspect
        

        temp_product_id = subs['shopify_product_id'].to_s
        temp_product_title = subs['product_title']
        temp_status = subs['status']
        temp_customer_id = subs['customer_id']
        temp_subscription_id = subs['id']
        if temp_status == 'ACTIVE' && (temp_product_id == monthly_box_id || temp_product_id == ellie_threepack_id)
          if !subs['next_charge_scheduled_at'].nil?
            temp_next_charge = subs['next_charge_scheduled_at']
            #figure out if next_charge_scheduled_at is this month
            puts "checking next charge scheduled_at, #{temp_next_charge}"
            can_we_skip = check_next_charge_this_month(temp_next_charge)
          else
            puts "next charge scheduled at is nil"
          end
          puts "--------"
          puts "#{temp_product_id}, #{temp_product_title}, #{temp_status}"
          if can_we_skip
            puts "Adding subscription #{temp_subscription_id} to skip array"
            my_sub_array.push(temp_subscription_id)
          end

        puts "--------"
        end
      end
      puts "Done with subscription parsing!"
      if !my_sub_array.empty?
        puts "WE have the following subscriptions to change the next_charge_date and associated charges"
        my_sub_array.each do |subelement|
        puts "Skipping subscription #{subelement}"
        skip_this_sub(subelement, $my_change_charge_header, $my_get_header, shopify_customer_id, uri, reason)
        end
      end
    end

  end
end

class SubscriptionDeleted
  extend FixMonth
  @queue = "subs_deleted"
  def self.perform(params)
    puts "Received a deleted subscription:"
    puts params.inspect
    subscription_info = params['subscription']
    puts subscription_info.inspect
    customer_id = subscription_info['customer_id']
    shopify_product_id = subscription_info['shopify_product_id']
    status = subscription_info['status']
    puts "customer_id = #{customer_id}, shopify_prod_id = #{shopify_product_id}"
    puts "Shopify Three months product id = #{SHOPIFY_THREE_MONTHS}"
    if shopify_product_id.to_i == SHOPIFY_THREE_MONTHS.to_i 
      puts "We have a three month subscription cancelled, we must un-tag this customer"
      puts "First we need to get the shopify_customer_id from Recharge"
      my_customer = HTTParty.get("https://api.rechargeapps.com/customers/#{customer_id}", :headers => $my_get_header)
      check_recharge_limits(my_customer)
      customer_info = my_customer.parsed_response
      puts customer_info.inspect
      customer_shopify_id  = customer_info['customer']['shopify_customer_id']
      puts "customer shopify id = #{customer_shopify_id}"
      ShopifyAPI::Base.site = "https://#{$apikey}:#{$password}@#{$shopname}.myshopify.com/admin"
      my_customer = ShopifyAPI::Customer.find(customer_shopify_id)
      customer_tags = my_customer.tags
      my_first_name = my_customer.first_name
      my_last_name = my_customer.last_name
      if !customer_tags.nil?
        tag_array = customer_tags.split(", ")
        minus_array = Array.new
        minus_array.push(CUST_TAG_THREE_MONTHS)
        tag_array = tag_array - minus_array
        if tag_array.length == 1
          new_tags = tag_array[0]
        else
          new_tags = tag_array.join(", ")
        end
        #New Code Floyd Wallace 9/5/2017 to take care of variants of 3MonTh(s) in tags
        new_tags = new_tags.gsub(/3months?\, /i, "")
        new_tags = new_tags.gsub(/3months?/i, "")

        puts "Now attempting to push tags to Shopify"
        my_customer.tags = new_tags
        my_customer.save
        puts "sleeping 3 secs"
        sleep 3
        puts "We have set customer #{my_first_name} #{my_last_name} tags = #{new_tags}"

      else
        puts "We have no tags to remove so not doing anything"

      end

    else
      puts "Sorry we untag only 3month customers"

    end 
  end
end


class SubscriptionListener
  extend FixMonth
  @queue = "subs_listener"
  def self.perform(params)
    puts "Received webhook subscription info:"
    puts params.inspect
    subscription_info = params['subscription']
    puts subscription_info.inspect
    customer_id = subscription_info['customer_id']
    shopify_product_id = subscription_info['shopify_product_id']
    status = subscription_info['status']
    puts "customer_id = #{customer_id}, shopify_prod_id = #{shopify_product_id}"
    puts "Shopify Three months product id = #{SHOPIFY_THREE_MONTHS}"
    if shopify_product_id.to_i == SHOPIFY_THREE_MONTHS.to_i 
      puts "We have a three month subscription that is, we must tag this customer"
      puts "First we need to get the shopify_customer_id from Recharge"
      #GET /customers/<id>
      my_customer = HTTParty.get("https://api.rechargeapps.com/customers/#{customer_id}", :headers => $my_get_header)
      check_recharge_limits(my_customer)
      customer_info = my_customer.parsed_response
      puts customer_info.inspect
      customer_shopify_id  = customer_info['customer']['shopify_customer_id']
      
      my_customer_tag = {
             "customer":  {
             "id": customer_shopify_id,
              
              "tags": CUST_TAG_THREE_MONTHS,
              "note": "Webhook tagging done through API"
              }
            }
      puts "customer shopify id = #{customer_shopify_id}"
      ShopifyAPI::Base.site = "https://#{$apikey}:#{$password}@#{$shopname}.myshopify.com/admin"
      my_customer = ShopifyAPI::Customer.find(customer_shopify_id)
      customer_tags = my_customer.tags
      my_first_name = my_customer.first_name
      my_last_name = my_customer.last_name
      #puts my_customer.inspect
      #puts customer_tags.inspect
      tag_array = Array.new
      new_tags = ""
      if !customer_tags.nil?
          tag_array = customer_tags.split(", ")
          tag_array.push(CUST_TAG_THREE_MONTHS)
          tag_array.uniq!
        else
          
          tag_array.push(CUST_TAG_THREE_MONTHS)
        end
        if tag_array.length == 1
          new_tags = tag_array[0]
          else
          new_tags = tag_array.join(", ")
          end
      my_customer.tags = new_tags
      puts "Sleeping 3 secs."
      sleep 3
      my_customer.save
      puts "We tagged the customer #{my_first_name} #{my_last_name} with: #{new_tags}"
    else
      puts "We don't have a three month subscription that is, no tagging"
    end

  end
end




class InfluencerBottle
  extend FixMonth
  @queue = "influencer_bottle"
  def self.perform(params)
    puts "Received the following from influencer bottle request: ==> #{params.inspect}"
    puts "-------------------"
    myaction = params['action']
    if myaction == "bottle_influencer_request"
      formdata = params['form_data']
      firstname = formdata['2']['value']
      lastname = formdata['3']['value']
      address1 = formdata['4']['value']
      address2 = formdata['5']['value']
      city = formdata['6']['value']
      state = formdata['7']['value']
      zip = formdata['8']['value']
      email = formdata['9']['value']
      phone = formdata['10']['value']
      #puts "Data = #{firstname}, #{lastname}, #{address1}, #{address2}, #{city}, #{state}, #{zip}, #{email}, #{phone} -- all done!"
      #check to see if customer exists as an upsell
      ShopifyAPI::Base.site = "https://#{$apikey}:#{$password}@#{$shopname}.myshopify.com/admin"
      my_customer = ShopifyAPI::Customer.search(query: email)
      my_raw_header = ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
      check_shopify_call_limit(my_raw_header, SHOP_WAIT)
      if my_customer != []
        puts "Customer exists in Shopify. Tagging then checking for duplicate orders."
        shopify_id = my_customer[0].attributes['id']
        puts "Customer Shopify ID = #{shopify_id}"
        customer_tags = my_customer[0].attributes['tags']
        puts "Customer tags = #{customer_tags}"
        #first get customer tags, then split into array, then add influencer tag, then uniq array!
        #then join to string, then submit tag string to tag_shopify_influencer
        tag_array = customer_tags.split(', ')
        tag_array << INFLUENCER_TAG
        tag_array.uniq!
        new_cust_tags = tag_array.join(", ")
        puts "Tagging Customer with new tags: #{new_cust_tags}"
        tag_shopify_influencer(shopify_id, new_cust_tags, $apikey, $password, $shopname, SHOP_WAIT)
        #Now check for duplicate orders
        puts "influencer bottle = #{INFLUENCER_BOTTLE}"
        create_new_order = check_duplicate_orders(shopify_id, $apikey, $password, $shopname, INFLUENCER_BOTTLE, SHOP_WAIT)
        puts "Create new order? #{create_new_order}"
        if create_new_order
          #puts "adding bottle order --"
          add_shopify_bottle_order(email, INFLUENCER_BOTTLE, BOTTLE_SKU, firstname, lastname, address1, address2, phone, city, state, zip, $apikey, $password, $shopname, INFLUENCER_BOTTLE_ID, INFLUENCER_ORDER, SHOP_WAIT)
        else
          puts "Duplicate orders exist for this month and year, cannot add order for this influencer"
        end



      else
        puts "Customer does not exist in Shopify, adding customer through API and then adding Bottle Request."
        #add customer here
        shopify_id = create_shopify_influencer_cust(firstname, lastname, email, phone, address1, address2, city, state, zip, $apikey, $password, $shopname, SHOP_WAIT)
        puts "New customer shopify_id = #{shopify_id}"

        #tag customer here
        #NEW_CUST_TAGS
        tag_shopify_influencer(shopify_id, NEW_CUST_TAGS, $apikey, $password, $shopname, SHOP_WAIT)


        #add order here
        add_shopify_bottle_order(email, INFLUENCER_BOTTLE, BOTTLE_SKU, firstname, lastname, address1, address2, phone, city, state, zip, $apikey, $password, $shopname, INFLUENCER_BOTTLE_ID, INFLUENCER_ORDER, SHOP_WAIT)
        puts "Done adding order for non-registered with shopify customer."


      end
     


    else
      puts "The action submitted must be bottle_influencer_request and instead the action was #{myaction}"
      puts "Sorry we cannot do anything."
    end

  end
end


class InfluencerBox
  extend FixMonth
  @queue = "influencer_box"
  def self.perform(params)
    puts "Got the following --->>>> #{params.inspect}"
    puts "--------------"
    myaction = params['action']
    #puts myaction
    if myaction == "influencer_order"
      myformdata = params['form_data']
      #puts myformdata.inspect
      mysportsbra = myformdata['2']['value']
      #puts mysportsbra
      mytops = myformdata['3']['value']
      #puts mytops
      myleggings = myformdata['4']['value']
      #puts myleggings
      myaccessories1 = myformdata['5']['value']
      #puts myaccessories1
      myaccessories2 = myformdata['6']['value']
      #puts myaccessories2
      myaccess_code = myformdata['7']['value']
      myfirstname = myformdata['8']['value']
      #puts myfirstname
      mylastname = myformdata['9']['value']
      #puts mylastname
      myaddress1 = myformdata['10']['value']
      #puts myaddress1
      myaddress2 = myformdata['11']['value']
      #puts myaddress2
      mycity = myformdata['12']['value']
      #puts mycity
      mystate = myformdata['13']['value']
      #puts mystate
      myzip = myformdata['14']['value']
      #puts myzip
      myemail = myformdata['15']['value']
      #puts myemail
      myphone = myformdata['16']['value']
      #puts myphone
      #First, check access code to see if it exists.
      #@code = ticket.find(myaccess_code)
      #puts myphone
      puts "Incoming Code is #{myaccess_code}"
      ticket = Tickets.where("influencer_code = ?", myaccess_code)
      puts ticket.inspect
      code_exists = ticket.exists?
      puts "Does code exist in database? : #{code_exists}"
      my_continue = false
      if code_exists == true
        
        puts "Got here eh."
        my_code = ticket[0]['influencer_code']
        #my_used =  ticket.inspect
        puts "code = #{my_code}"
        my_used = ticket[0]['code_used']
        my_id = ticket[0]['id']
        puts "Here now"
        puts "my_id = #{my_id}"
        puts my_used.inspect
        #code_used_already = ticket.code_used
        #puts code_used_already
        #puts "Code exists"
        if my_used == false
          puts "Allowing user to submit an influencer box request."
          my_continue = true
          #ticket.code_used = "t"
          #ticket.save
          #ticket.update_attributes(code_used: true)
          #Tickets.update(my_id, true) 
          #ticket.attribute = true
          #ticket.save(:validate => false)
          Tickets.where(id: my_id).update_all(code_used: true)
        end
      end


      if my_continue
      ShopifyAPI::Base.site = "https://#{$apikey}:#{$password}@#{$shopname}.myshopify.com/admin"
      my_customer = ShopifyAPI::Customer.search(query: myemail)
      #puts my_customer.inspect
      
      #puts ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
      #my_raw_header = ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
      #puts "Shopify Header Info: #{my_raw_header}"

      #my_url = "https://#{$apikey}:#{$password}@#{$shopname}.myshopify.com/admin"
      #my_addon = "/customers/search.json?query=#{myemail}"
      #total_url = my_url + my_addon
      #puts total_url
      #response = HTTParty.get(total_url)
      #puts response
      my_raw_header = ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
      check_shopify_call_limit(my_raw_header, SHOP_WAIT)
      #puts "Shopify Header Info: #{my_raw_header}"
      
      #puts "my_customer = #{my_customer.inspect}"
      
      
      if my_customer != []
        puts "Customer exists in Shopify. Tagging then checking for duplicate orders."
        #returned_email = my_customer[0].attributes['email']
        shopify_id = my_customer[0].attributes['id']
        puts "Customer Shopify ID = #{shopify_id}"
        customer_tags = my_customer[0].attributes['tags']
        puts "Customer tags = #{customer_tags}"
        #first get customer tags, then split into array, then add influencer tag, then uniq array!
        #then join to string, then submit tag string to tag_shopify_influencer
        tag_array = customer_tags.split(', ')
        tag_array << INFLUENCER_TAG
        tag_array.uniq!
        new_cust_tags = tag_array.join(", ")
        puts "Tagging Customer with new tags: #{new_cust_tags}"
        tag_shopify_influencer(shopify_id, new_cust_tags, $apikey, $password, $shopname, SHOP_WAIT)



        #POST /admin/orders.json

        #add check to make sure influencer has only one order this month

        #GET /admin/customers/#{id}/orders.json
        puts "influencer product = #{INFLUENCER_PRODUCT}"
        #commented out as we no longer need to check for dupes influencer code controls that
        #create_new_order = check_duplicate_orders(shopify_id, $apikey, $password, $shopname, INFLUENCER_PRODUCT, SHOP_WAIT)
        
        create_new_order = true
        puts "Create new order? #{create_new_order}"

        if create_new_order
          add_shopify_order(myemail, myaccessories1, myaccessories2, myleggings, mysportsbra, mytops, myfirstname, mylastname, myaddress1, myaddress2, myphone, mycity, mystate, myzip, $apikey, $password, $shopname, PROD_ID, BOX_SKU, INFLUENCER_ORDER, SHOP_WAIT, INFLUENCER_PRODUCT)
        else
          puts "Duplicate orders exist for this month and year, cannot add order for this influencer"
        end

     
      
      
      

      else
        puts "Customer does not exist in Shopify, adding customer through API and then adding Order"
        #add customer here
        shopify_id = create_shopify_influencer_cust(myfirstname, mylastname, myemail, myphone, myaddress1, myaddress2, mycity, mystate, mystate, $apikey, $password, $shopname, SHOP_WAIT)
        puts "New customer shopify_id = #{shopify_id}"

        #tag customer here
        #NEW_CUST_TAGS
        tag_shopify_influencer(shopify_id, NEW_CUST_TAGS, $apikey, $password, $shopname, SHOP_WAIT)


        #add order here
        add_shopify_order(myemail, myaccessories1, myaccessories2, myleggings, mysportsbra, mytops, myfirstname, mylastname, myaddress1, myaddress2, myphone, mycity, mystate, myzip, $apikey, $password, $shopname, PROD_ID, BOX_SKU, INFLUENCER_ORDER, SHOP_WAIT, INFLUENCER_PRODUCT)
        puts "Done adding order for non-registered with shopify customer."
      end
    else  
        puts "No valid access code for this product. Sorry cannot add influencer order"
    end #my_continue
     


    else
      puts "Sorry, action must be influencer_order and it is #{myaction}."
      puts "We cannot process this request."
    end

  end
end

class ReactivateCustomer
  extend FixMonth
  @queue = "reactivate_cust"
  def self.perform(params)
    puts "Got the following --> #{params.inspect}"
    shopify_id = params['shopify_id']
    all_subscriptions = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers =>  $my_get_header)
    
    
    mysubs = all_subscriptions.parsed_response['subscriptions']
    restart_id = ""
    canceled_at = DateTime.strptime('2005-01-01', '%Y-%m-%d')
    
    mysubs.each do |subs|
      if subs['status'] == 'CANCELLED'
        if subs['product_title'] =~ /\d\sMonth/i || subs['product_title'] =~ /box/i
          puts "------------"
          puts subs.inspect
          puts "------------"
          temp_str = subs['cancelled_at']
          #puts temp_str
          temp_date = DateTime.strptime(temp_str, '%Y-%m-%d %H:%M:%S')
          #puts temp_date.inspect
          #puts canceled_at.inspect
          if temp_date > canceled_at
            #puts "temp is more recent"
            canceled_at = DateTime.strptime(temp_str, '%Y-%m-%d %H:%M:%S')
            restart_id =subs['id']
            end

          
          end
        end
      
      end

      if restart_id != ""
        puts "The most recent canceled subscription is #{restart_id}"
        puts "Restarting that subscription"
        my_data = {}.to_json
        my_restart = HTTParty.post("https://api.rechargeapps.com/subscriptions/#{restart_id}/activate", :headers => $my_change_charge_header, :body => my_data)
        puts "========================="
        puts "Status of restarting subscription #{restart_id}: #{my_restart.inspect}"
        puts "========================="
        check_recharge_limits(my_restart)

      else
        puts "Sorry, there was no valid canceled subscription to restart."
      end

  end
end

class SkipPreviewMonth
  extend FixMonth
  @queue = "skip_preview_month"
  def self.perform(params)
    puts "We have the following params --> #{params.inspect}"
    shopify_id = params['shopify_id']
    action = params['action']
    if action == "skip_next_month"
      my_today_date = Date.today
      next_month = my_today_date >> 1
      current_month = my_today_date.strftime('%B')
      next_month_name = next_month.strftime('%B')
      puts "This is month #{current_month} and next month is #{next_month_name}"
      get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => $my_get_header)   
      my_api_info = get_sub_info.response['x-recharge-limit']
      puts "Recharge says we have the following api call limits: #{my_api_info}"
      api_array = my_api_info.split('/')
      #puts api_array.inspect
      my_numerator = api_array[0].to_i
      my_denominator = api_array[1].to_i
      api_percentage_used = my_numerator/my_denominator.to_f
      puts "Which is #{api_percentage_used.round(2)}"
      if api_percentage_used > 0.6
        puts "Must sleep #{RECH_WAIT} seconds"
        sleep RECH_WAIT.to_i
      end
      mysubs = get_sub_info.parsed_response
      subscriptions = mysubs['subscriptions']
      subscriptions.each do |mys|
        if mys['status'] != "CANCELLED"
          puts "-------------"
          puts mys.inspect           
          puts "-------------"
          puts ""
          puts "======================="
          next_charge_scheduled = mys['next_charge_scheduled_at']
          next_charge_date = DateTime.strptime(next_charge_scheduled, '%Y-%m-%dT%H:%M:%S')
          next_charge_month = next_charge_date.strftime('%B')
          puts "next_charge_month is #{next_charge_month} and system next month is #{next_month_name}"
          if next_month_name == next_charge_month
            puts "We can skip next month as a preview"
            subscription_id = mys['id']
            puts "Skipping Subscription ID #{subscription_id}"
            skip_to_next_month(subscription_id, next_charge_date, $my_change_charge_header)
          else
            puts "We can't skip next month, the next charge is scheduled at: #{next_charge_scheduled}"
          end
          puts "======================="
        end
      end
      


    else
      puts "Action is #{action}, not skip_next_month, we cannot do anything, wrong parameters sent"  
    end

  end

end




class PreviewMonth
  extend FixMonth
  @queue = "preview_month"
  def self.perform(preview_month_data)
    puts "Now processing customer preview request ..."
    puts preview_month_data.inspect
    my_action = preview_month_data['action']
    if my_action == "get_preview_month"
      last_day_current_month = Date.today.end_of_month
      
      puts "Last day of current month = #{last_day_current_month}"
      shopify_id = preview_month_data['shopify_id']
      new_date = preview_month_data['ship_date']
      cust_requested_date = DateTime.strptime(new_date, '%Y-%m-%d')
      cust_month = cust_requested_date.strftime('%B')
      get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => $my_get_header)
      sleep RECH_WAIT.to_i
      puts "Sleeping #{RECH_WAIT} seconds."
      mysubs = get_sub_info.parsed_response
      allsubscriptions = mysubs['subscriptions']
      allsubscriptions.each do |subs|
          if subs['status'] != "CANCELLED" && !!(subs['product_title'] =~/box/i)
            puts "------------------"
            puts subs.inspect
            next_charge = subs['next_charge_scheduled_at']
            puts "Next Charge Scheduled at: #{next_charge}"
            #2017-06-20T00:00:00
            actual_scheduled = DateTime.strptime(next_charge, '%Y-%m-%dT%H:%M:%S')
            actual_month = actual_scheduled.strftime('%B')

            puts "Customer Month Requested is #{cust_month} and actual charge month is #{actual_month}"
            # Check to see if actual_scheduled is greater than the last day of the month
            puts "Last Day of the month is #{last_day_current_month.to_s}"
            

            if last_day_current_month >= actual_scheduled
              puts "We can't allow customer to accept next month, looks like customer's next charge date is still pending last three days of the month."
            elsif     
              subscription_id = subs['id']
              puts "Accepting Next Month for subscription id #{subscription_id}" 

              body = { "date" => new_date }.to_json
              
              reset_charge_date_post(subscription_id, $my_change_charge_header, body)

            end
            puts "------------------"
          end
        end
      


    else
      puts "Sorry, the action is #{my_action}, not get_preview_month therefore we cannot process this request."
    end
  end
end

class UpsellRemove
  extend FixMonth
  @queue = "upsellremove"
  def self.perform(remove_add_on_data)
    puts "Now removing add on to box ..."
    puts remove_add_on_data.inspect
    endpoint_info = remove_add_on_data['endpoint_info']
    if endpoint_info == "upsell_remove"
      product_title = remove_add_on_data['shopify_product_title']
      shopify_id = remove_add_on_data['shopify_id']
      product_id = remove_add_on_data['shopify_product_id']
      get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => $my_get_header)
      puts "Must sleep #{RECH_WAIT} seconds"
      sleep RECH_WAIT.to_i
      subscriber_stuff = get_sub_info.parsed_response
      #puts subscriber_stuff.inspect
      subscriptions = subscriber_stuff['subscriptions']
      #puts subscriptions.inspect
      subscriptions.each do |mysub|
        if mysub['status'] != "CANCELLED" && mysub['shopify_product_id'].to_i == product_id.to_i
          puts "-----------"
          puts mysub.inspect
          puts "Product Title sent = #{product_title}"
          puts "Product_id sent = #{product_id}"
          puts "-----------"
          cancel_subscription_id = mysub['id']
          puts "Canceling subscription #{cancel_subscription_id}"
          #-- now cancel the subscription.
          #POST /subscriptions/<subscription_id>/cancel
          my_data = {"cancellation_reason" => "Customer Through API/Website"}.to_json
          my_cancel = HTTParty.post("https://api.rechargeapps.com/subscriptions/#{cancel_subscription_id}/cancel", :headers => $my_change_charge_header, :body => my_data)
          my_response = my_cancel.parsed_response
          puts "Recharges sent back: #{my_response}"
          puts "Must Sleep now #{RECH_WAIT} seconds"
          sleep RECH_WAIT.to_i

          end
        end

    else
      puts "We can't do anything, the endpoint_info is #{endpoint_info} not upsell_remove"
      puts "Sorry but rules are rules."
    end

  end

end

class ChangeCustSizes
  extend FixMonth
  @queue = "changecustsizes"
  def self.perform(cust_sizes_data)
    puts "We are Processing the Customer Size Data"
    puts cust_sizes_data.inspect
    my_action = cust_sizes_data['action']
    my_shopify_id = cust_sizes_data['shopify_id']
    cust_sizes_hash = cust_sizes_data['cust_sizes']
    puts "my_action = #{my_action}"
    if my_action == "change_cust_sizes"
      puts "my_shopify_id = #{my_shopify_id}"
      puts "cust_sizes_hash = #{cust_sizes_hash.inspect}"
      bottom_sizes = cust_sizes_hash['bottom_size']
      #puts "bottom_sizes = #{bottom_sizes}"
      bottom_sizes = bottom_sizes.gsub(/\s+/, " ").strip
      top_sizes = cust_sizes_hash['top_size']
      top_sizes = top_sizes.gsub(/\s+/, " ").strip
      bra_sizes = cust_sizes_hash['bra_size']
      bra_sizes = bra_sizes.gsub(/\s+/, " ").strip

      #check to see if you have jacket_size key in hash
      if cust_sizes_hash.key?("jacket_size")
        jacket_sizes = cust_sizes_hash['jacket_size']
        jacket_sizes = jacket_sizes.gsub(/\s+/, " ").strip
        #puts jacket_sizes.inpsect

        puts "Cust Sizes now bottom=#{bottom_sizes}, top=#{top_sizes}, bra=#{bra_sizes}, jacket=#{jacket_sizes}"
        my_data_recharge = {"properties" => [{"name" => "leggings", "value" => bottom_sizes }, {"name" => "sports-bra", "value" =>bra_sizes }, {"name" => "tops", "value" => top_sizes }, {"name" => "sports-jacket", "value" => jacket_sizes }]}.to_json
      else
        puts "Cust Sizes now bottom=#{bottom_sizes}, top=#{top_sizes}, bra=#{bra_sizes}"
        my_data_recharge = {"properties" => [{"name" => "leggings", "value" => bottom_sizes }, {"name" => "sports-bra", "value" =>bra_sizes }, {"name" => "tops", "value" => top_sizes }]}.to_json
      end
      
      #cust_id = request_recharge_id(my_shopify_id, $my_get_header)
      #puts "cust_id =#{cust_id}"
      #puts "sleeping 3"
      #sleep 3
      #address_id = request_address_id(cust_id, $my_get_header)
      #puts "sleeping 3 again"
      #sleep 3

      
      #my_subscriptions = Array.new

      
      
      
      puts my_data_recharge
      #send_size_change_recharge = HTTParty.put("https://api.rechargeapps.com/subscriptions/#{my_subscription_id}", :headers => $my_change_charge_header, :body => my_data_recharge)
      #puts send_size_change_recharge

      my_subscriptions = request_subscriber_id(my_shopify_id, $my_get_header, SHOPIFY_ELLIE_3PACK_ID, SHOPIFY_MONTHLY_BOX_ID, SHOPIFY_3MONTH_ID)
      puts "We have the following subscription ids:"
      my_subscriptions.each do |subid|
        puts "Changing sizes for subscription #{subid}"
        send_size_change_recharge = HTTParty.put("https://api.rechargeapps.com/subscriptions/#{subid}", :headers => $my_change_charge_header, :body => my_data_recharge)
        check_recharge_limits(send_size_change_recharge)
        puts send_size_change_recharge.inspect

        end
      puts "--------------------------------------------------"
      puts "All done changing size for customer's subscriptions!"

    else
      puts "Action is #{my_action}"
      puts "We can't do anything, must be change_cust_sizes"

      end

  end

end

class UpsellPreviewMonth
  extend FixMonth
  @queue = "upsellpreview"
  def self.perform(params)
    puts "Unpacking the Preview Month upsell info"
    puts params.inspect
    puts "---------------"
    my_action = params['endpoint_info']
    variant_id = params['shopify_variant_id']
    shopify_id = params['shopify_id']
    if my_action == "cust_upsell" && variant_id != '' && !variant_id.nil?
      #go ahead and do stuff
      puts "processing this order"
      cust_id = request_recharge_id(shopify_id, $my_get_header)
      puts "cust_id =#{cust_id}"
      address_id = request_address_id(cust_id, $my_get_header)
      ShopifyAPI::Base.site = "https://#{$apikey}:#{$password}@#{$shopname}.myshopify.com/admin"
      #puts "OK HERE"
      my_variant = ShopifyAPI::Variant.find(variant_id)
      puts "found variant #{my_variant.id}"
      my_customer_size = my_variant.option1
      puts "Customer size = #{my_customer_size}"
      #create customer line item properties for history
      line_item_properties = [ { "name" => "size", "value" => my_customer_size } ]
      my_raw_price = my_variant.price.to_f
      puts "my_raw_price = #{my_raw_price}"
      my_true_variant_id = variant_id.to_i
      true_price = my_raw_price
      my_product_id = my_variant.product_id.to_i
      my_product = ShopifyAPI::Product.find(my_product_id)
      my_product_title = my_product.title
      puts "Found #{my_product_title}"
      #puts ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
      my_raw_header = ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
      puts "Shopify Header Info: #{my_raw_header}"
      my_array = my_raw_header.split('/')
      my_result = my_array[0].to_i/my_array[1].to_f
      if my_result > 0.75
        puts "Too many calls, must sleep #{SHOP_WAIT} seconds"
        sleep SHOP_WAIT
      end
      puts "my_product_title=#{my_product_title}, my_true_variant_id=#{my_true_variant_id}, true_price=#{true_price}, my_product_id = #{my_product_id}"
      #hard-code quantity=1 and today's date for next-charge
      quantity = 1
      preview = true
      
      submit_order_hash = check_for_duplicate_subscription(shopify_id, my_true_variant_id, my_product_title, $my_get_header, preview)
      submit_order_flag = submit_order_hash['process_order']
      process_order_date = submit_order_hash['charge_date']
      puts "submit_order_flag = #{submit_order_flag}"
      


      if submit_order_flag == false
          puts "This is a duplicate order, I can't send to Recharge as there already exists an ACTIVE subscription with this variant_id #{variant_id} or title #{product_title}."
      else
          puts "OK, submitting order"
          data_send_to_recharge = {"address_id" => address_id, "next_charge_scheduled_at" => process_order_date, "product_title" => my_product_title, "shopify_product_id" => my_product_id,  "price" => true_price, "quantity" => "#{quantity}", "shopify_variant_id" => my_true_variant_id, "order_interval_unit" => "month", "order_interval_frequency" => "1", "charge_interval_frequency" => "1", "number_charges_until_expiration" => "1", "properties" => line_item_properties }.to_json
          puts data_send_to_recharge
          puts "sleeping #{RECH_WAIT}"
          sleep RECH_WAIT.to_i
          puts "Submitting order as a new upsell subscription"
          send_upsell_to_recharge = HTTParty.post("https://api.rechargeapps.com/subscriptions", :headers => $my_change_charge_header, :body => data_send_to_recharge)
          puts send_upsell_to_recharge.inspect
        end


    else
      puts "WARNING ERROR: Action is #{my_action} and it must be cust_upsell, or else variant_id is nil and variant_id = #{variant_id}, we can't do anything here, not processing this upsell."
    end
  end
end

class UpsellProcess
  extend FixMonth
  @queue = "upsellprocess"
  def self.perform(upsellprocess_data)
    puts "Unpacking upsellprocess_data:"
    puts upsellprocess_data.inspect
    my_action = upsellprocess_data['endpoint_info']
    variant_id = upsellprocess_data['shopify_variant_id']
    preview = false
    #check for correct action and end if incorrect
    if my_action == "cust_upsell" && variant_id != '' && !variant_id.nil?
      #go ahead and do stuff
      puts "processing this order"
      shopify_id = upsellprocess_data['shopify_id']

      variant_id = upsellprocess_data['shopify_variant_id']
      puts "variant_id=#{variant_id}"
      puts "processing customer upsell products"
      cust_id = request_recharge_id(shopify_id, $my_get_header)
      puts "cust_id =#{cust_id}"
      address_id = request_address_id(cust_id, $my_get_header)
      #New code 5-8-17: take variant_id and request to Shopify
      #Product_title, product_id, price
      #puts "https://#{$apikey}:#{$password}@#{$shopname}.myshopify.com/admin"
      ShopifyAPI::Base.site = "https://#{$apikey}:#{$password}@#{$shopname}.myshopify.com/admin"
      #puts "OK HERE"
      my_variant = ShopifyAPI::Variant.find(variant_id)
      puts "found variant #{my_variant.id}"
      my_customer_size = my_variant.option1
      puts "Customer size = #{my_customer_size}"
      #create customer line item properties for history
      line_item_properties = [ { "name" => "size", "value" => my_customer_size } ]
      my_raw_price = my_variant.price.to_f
      puts "my_raw_price = #{my_raw_price}"
      my_true_variant_id = variant_id.to_i
      true_price = my_raw_price
      my_product_id = my_variant.product_id.to_i
      my_product = ShopifyAPI::Product.find(my_product_id)
      my_product_title = my_product.title
      puts "Found #{my_product_title}"
      #puts ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
      my_raw_header = ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
      puts "Shopify Header Info: #{my_raw_header}"
      my_array = my_raw_header.split('/')
      my_result = my_array[0].to_i/my_array[1].to_f
      if my_result > 0.75
        puts "Too many calls, must sleep #{SHOP_WAIT} seconds"
        sleep SHOP_WAIT
      end



      puts "my_product_title=#{my_product_title}, my_true_variant_id=#{my_true_variant_id}, true_price=#{true_price}, my_product_id = #{my_product_id}"
      #hard-code quantity=1 and today's date for next-charge
      quantity = 1
      tomorrow = Date.today + 1

      my_charge_date = tomorrow.strftime("%Y-%m-%d")
      puts "Tommorow is #{my_charge_date}"

      #check_for_duplicate_subscription(cust_id, address_id, shopify_id, my_true_variant_id, my_product_id, my_product_title, true_price, $my_get_header, $my_change_charge_header, line_item_properties)

      submit_upsell_request(cust_id, address_id, shopify_id, my_true_variant_id, my_product_id, my_product_title, true_price, $my_get_header, $my_change_charge_header, line_item_properties)

      #data_send_to_recharge = {"address_id" => address_id, "next_charge_scheduled_at" => next_charge_scheduled, "product_title" => product_title, "price" => price_float, "quantity" => quantity, "shopify_variant_id" => variant_id, "order_interval_unit" => "month", "order_interval_frequency" => "1", "charge_interval_frequency" => "1"}.to_json
      #puts data_send_to_recharge


    else
      #don't do anything, incorrect parameters
      puts "We can't do anything: endpoint_info = #{my_action}"
    end
    puts "Done with adding upsell for this customer!"
  end
end


class Upsell
  extend FixMonth
  @queue = "upsell"
  def self.perform(upsell_data)
    puts "Unpacking request data"
    puts upsell_data.inspect
    action = upsell_data['action']
    shopify_id = upsell_data['shopify_id']
    product_title = upsell_data['product_title']

    next_charge = upsell_data['next_charge']
    price = upsell_data['price']
    quantity = upsell_data['quantity']
    sku = upsell_data['sku'].to_i
    shopify_variant_id = upsell_data['shopify_variant_id'].to_i
    size = upsell_data['size']
    #create properties array here, be CAREFUL MUST BE NAME-VALUE pairs
    property_json = {"name" => "size", "value" => "S"}
    properties = [property_json]


    if action == 'cust_upsell'
        puts "processing customer upsell products"
        cust_id = request_recharge_id(shopify_id, $my_get_header)
        address_id = request_address_id(cust_id, $my_get_header)
        #puts product_title, next_charge, price, quantity, shopify_variant_id, size
        #redo date into something Recharge can handle.
        next_charge_scheduled_at_date = DateTime.strptime(next_charge, "%m-%d-%Y")
        next_charge_scheduled = next_charge_scheduled_at_date.strftime("%Y-%m-%d")
        #next_charge_scheduled = "#{next_charge_scheduled}"
        data_send_to_recharge = {"address_id" => address_id, "next_charge_scheduled_at" => next_charge_scheduled, "product_title" => product_title, "price" => price, "quantity" => quantity, "shopify_variant_id" => shopify_variant_id, "sku" => sku, "order_interval_unit" => "month", "order_interval_frequency" => "1", "charge_interval_frequency" => "1", "number_charges_until_expiration" => "1", "properties" => properties}.to_json
        puts data_send_to_recharge


        #puts $my_change_charge_header
        #Before sending, request all subscriptions and avoid submitting duplicates.


        submit_order_flag = check_for_duplicate_subscription(shopify_id, shopify_variant_id, $my_get_header)

        if submit_order_flag
          puts "Sleeping #{RECH_WAIT} seconds."
          sleep RECH_WAIT.to_i
          puts "Submitting order as a new upsell subscription"
          send_upsell_to_recharge = HTTParty.post("https://api.rechargeapps.com/subscriptions", :headers => $my_change_charge_header, :body => data_send_to_recharge)
          puts send_upsell_to_recharge.inspect
        else
          puts "This is a duplicate order, I can't send to Recharge as there already exists an ACTIVE subscription with this variant_id #{shopify_variant_id}."
        end


    else
      puts "Wrong action received from browser: #{action}, action must be cust_upsell ."
    end

  end
end


class UnSkip
  extend FixMonth
  @queue = "unskip"
  def self.perform(unskip_data)
    puts unskip_data.inspect
    shopify_id = unskip_data['shopify_id']
    action = unskip_data['action']
    #first check to see if we are doing the correct action
    if action == 'unskip_month'
      puts "shopify_id = #{shopify_id}"
      #Get alt_title
      current_month = Date.today.strftime("%B")
      alt_title = "#{current_month} VIP Box"
      orig_sub_date = ""
      my_subscription_id = ''

      my_subscriber_data = request_subscriber_id(shopify_id, $my_get_header, alt_title)
      orig_sub_date = my_subscriber_data['orig_sub_date']
      my_subscription_id = my_subscriber_data['my_subscription_id']
      puts "My Subscriber ID = #{my_subscription_id}, my original date = #{orig_sub_date}"


     puts "Must sleep for #{RECH_WAIT} secs"
     sleep RECH_WAIT.to_i

     my_customer_email = request_customer_email(shopify_id, $my_get_header)

     puts "My customer_email = #{my_customer_email}"
     puts "Must sleep for #{RECH_WAIT} secs again"
     sleep RECH_WAIT.to_i
     customer_next_subscription_date = DateTime.parse(orig_sub_date)
     customer_previous_month = customer_next_subscription_date << 1
     customer_previous_month_name = customer_previous_month.strftime("%B")
     puts "Customer Previous Month Name = #{customer_previous_month_name}"
     puts "Current Month = #{current_month}"
     if current_month == customer_previous_month_name
        puts "Unskipping Month"
        my_data = ""
        my_data = unskip_month_recharge(customer_next_subscription_date)
        puts my_data.inspect
        puts "My Subscription ID = #{my_subscription_id}"
        reset_charge_date_post(my_subscription_id, $my_change_charge_header, my_data)


     else
        puts "Months to unskip don't match, not doing anything"

     end


    else
      puts "Sorry that action is not unskip_month we won't do anything"

    end



  end
end


class ChooseDate
  extend FixMonth
  @queue = "choosedate"
  def self.perform(choosedate_data)
    puts choosedate_data.inspect
    shopify_id = choosedate_data['shopify_id']
    new_date = choosedate_data['new_date']
    action = choosedate_data['action']

    puts "shopify_id = #{shopify_id}"
    puts "new_date = #{new_date}"
    puts "action = #{action}"
    my_today_date = Date.today
    puts "Today's Date is #{my_today_date.to_s}"
    if action == 'change_date'
      puts "Changing the date for charge/shipping"
      #Get alt_title
      current_month = Date.today.strftime("%B")
      alt_title = "#{current_month} VIP Box"
      orig_sub_date = ""
      my_subscription_id = ''
      plain_title = "#{current_month} Box"
      alt_title = "#{current_month} VIP Box"
      three_month_box = "VIP 3 Monthly Box"
      old_three_month_box = "VIP 3 Month Box"
      orig_sub_date = ""
      my_subscription_id = ''
      get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => $my_get_header)
      mysubs = get_sub_info.parsed_response
      puts mysubs
      puts "Must sleep for #{RECH_WAIT} seconds"
      sleep RECH_WAIT.to_i
      subsonly = mysubs['subscriptions']
      subsonly.each do |subs|
        if subs['status'] != "CANCELLED"
            product_title = subs['product_title']
            if product_title == "VIP 3 Monthly Box" || product_title == "Monthly Box" || product_title ==   alt_title || product_title = plain_title || product_title == old_three_month_box
              puts subs.inspect
              my_subscription_id = subs['id']
              orig_sub_date = subs['next_charge_scheduled_at']
              puts "subscription created at #{subs['created_at']}"
              temp_sub_created = subs['created_at'].split('T')
              my_temp_sub_create = temp_sub_created[0]
              puts my_temp_sub_create
              subscription_created_at = Date.parse(my_temp_sub_create)
              sub_created_at_str = subscription_created_at.strftime('%B')
              today_str = my_today_date.strftime('%B')
              puts "Subscription created at: #{sub_created_at_str}, today month is #{today_str}"
              puts "#{my_subscription_id}, #{orig_sub_date}"
              if today_str != sub_created_at_str
                check_change_date_ok(current_month, my_subscription_id, orig_sub_date, new_date,$my_change_charge_header)
              elsif
                puts "We cannot change date, today month is #{today_str} and subscription_created_at is month #{sub_created_at_str} "
                end
              end
          end
        end


    else
      puts "Action must be change_date, and action is #{action} so we can't do anything."
    end

  end
end

class SkipMonth
  extend FixMonth
  @queue = "skipthismonth"
  def self.perform(skip_month_data)
    puts skip_month_data.inspect
    action = skip_month_data['action']
    shopify_id = skip_month_data['shopify_id']

    if action == 'skip_month'
      current_month = Date.today
      previous_month = current_month << 1
      last_day_prior = previous_month.end_of_month

      puts "Got Here to request data from Recharge."

      get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}&limit=250", :headers => $my_get_header)
      mysubs = get_sub_info.parsed_response
      puts mysubs.inspect
      puts "----------------"
      puts get_sub_info.inspect
      puts "Must sleep for #{RECH_WAIT} seconds"
      sleep RECH_WAIT.to_i
      subsonly = mysubs['subscriptions']
      puts subsonly.inspect
      puts "OK, now looping through all subscriptions for this customer:"
      puts "product_id         status      product_title    created_at"
      puts "==========================================================="
      subsonly.each do |subs|
        #puts subs.inspect
        product_id = subs['shopify_product_id']
        status = subs['status']
        product_title = subs['product_title']
        created_at = subs['created_at']
        continue_skipping = false
        created_at_date = DateTime.strptime(created_at, "%Y-%m-%dT%H:%M:%S")
        puts "#{product_id}, #{status}, #{product_title}, #{created_at}"
        if created_at_date > last_day_prior
            puts "Sorry, the created_at_date is #{created_at} which is this month and we cannot"
            puts "Skip the month when a subscription is in its first month as it creates a new subscription which is bad"
            continue_skipping = false
          else
            puts "OK we can skip this subscription if other conditions check out, it was"
            puts "created_at #{created_at} which was prior to this month"
            continue_skipping = true
          end

        if subs['status'] != "CANCELLED" && subs['status'] != "ONETIME"
            #product_title = subs['product_title']
            puts product_id.to_i, SHOPIFY_MONTHLY_BOX_ID.to_i, SHOPIFY_ELLIE_3PACK_ID.to_i, continue_skipping
            if (product_id.to_i == SHOPIFY_MONTHLY_BOX_ID.to_i  || product_id.to_i == SHOPIFY_ELLIE_3PACK_ID.to_i || product_id.to_i == SHOPIFY_MONTHLY_BOX_AUTORENEW_ID.to_i) && continue_skipping
              puts subs.inspect
              my_subscription_id = subs['id']
              orig_sub_date = subs['next_charge_scheduled_at']
              puts "#{my_subscription_id}, #{orig_sub_date}"
              #Now check to see if the subscriber can skip to next month, i.e. their current
              #next_subscription date is this month. If not, do nothing.
              my_sub_date = DateTime.parse(orig_sub_date)
              current_month_str = current_month.strftime("%B")
              subscriber_actual_next_charge_month = my_sub_date.strftime("%B")
              puts "Subscriber next charge month = #{subscriber_actual_next_charge_month}"
              puts "Current month is #{current_month_str}"
              if current_month_str == subscriber_actual_next_charge_month
                 puts "Skipping charge to next month"
                 puts "So Happy We can Skip for this customer!"
                 skip_to_next_month(my_subscription_id, my_sub_date, $my_change_charge_header)

              else
                 puts "We can't do anything, the next_charge_month is #{subscriber_actual_next_charge_month} which is not the current month -- #{current_month_str}"
              end


            end
          end
        end

    else
      puts "We can't do anything, action is #{action} which is not skip_month dude!"
    end

  end

end


class MyParamHandler
  @queue = "skipbox"
  def self.perform(shopify_id)
    #get the recharge customer_id
    #recharge_access_token = ENV['RECHARGE_ACCESS_TOKEN']
    #puts "recharge_access_token = #{$recharge_access_token}"
    @my_header = {
            "X-Recharge-Access-Token" => "#{$recharge_access_token}"
        }
    @my_change_charge_header = {
            "X-Recharge-Access-Token" => "998616104d0b4668bcffa0cfde15392e",
            "Accept" => "application/json",
            "Content-Type" =>"application/json"
        }

    get_info = HTTParty.get("https://api.rechargeapps.com/customers?shopify_customer_id=#{shopify_id}", :headers => @my_header)
    my_info = get_info.parsed_response
    puts my_info.inspect
    my_recharge_id = my_info['customers'][0]['id']
    puts my_recharge_id
    puts "Must sleep for two seconds"
    sleep 2
    #get all charges to find right one
    charges_customer = HTTParty.get("https://api.rechargeapps.com/charges?customer_id=#{my_recharge_id}&status=queued", :headers => @my_header )
    all_charges = charges_customer.parsed_response
    puts "Must sleep again for two seconds"
    sleep 2

    puts all_charges['charges'].inspect

    my_charges = all_charges['charges']
    #puts my_charges.inspect
    #puts my_charges.class
    #puts my_charges.size

    #Get the Alternate title, pattern April VIP Box etc.
    current_month = Date.today.strftime("%B")
    alt_title = "#{current_month} VIP Box"
    alt_3month_title = "VIP 3 Monthly Box"
    old_3month_box = "VIP 3 Month Box"
    alt_month_plain_title = "#{current_month} Box"

    #Define scope of subscription_id to use later
    subscription_id = ""


    my_charges.each do |myc|
      #puts myc.inspect
      #puts "----------"
      #puts myc['line_items'].inspect
      #puts "-----------"
      myc['line_items'].each do |line|
        puts ""
        puts line.inspect


        if line['title'] == "Monthly Box" || line['title'] == alt_title || line['title'] == alt_3month_title || line['title'] == alt_month_plain_title || line['title'] == old_3month_box
          subscription_id = line['subscription_id']
          puts "Found Subscription id = #{subscription_id}"
          #Here we skip the subscription to the next month
          subscription_info = HTTParty.get("https://api.rechargeapps.com/subscriptions/#{subscription_id}", :headers => @my_header )
          my_subscription = subscription_info.parsed_response
          puts "Gotta sleep again sorry two seconds"
          sleep 2
          subscription_date = my_subscription['subscription']['next_charge_scheduled_at']
          puts "subscription_date = #{subscription_date}"
          my_sub_date = DateTime.parse(subscription_date)
          #Check to make sure they are not skipping next month
          subscriber_actual_next_charge_month = my_sub_date.strftime("%B")
          puts subscriber_actual_next_charge_month
          puts current_month
          if subscriber_actual_next_charge_month == current_month

            my_next_month = my_sub_date >> 1
            my_day_month = my_sub_date.strftime("%e").to_i

            next_month_name = my_next_month.strftime("%B")
            #puts next_month_name
            #Constructors for new subscription charge date
            my_new_year = my_next_month.strftime("%Y")
            my_new_month = my_next_month.strftime("%m")
            my_new_day = my_next_month.strftime("%d")

            month_31 = ["January", "March", "May", "July", "August", "October", "December"]
            month_30 = ["April", "June", "September", "November"]

            if month_31.include? next_month_name
              puts "No need to adjust next month day, it has 31 days!"
              #Just advance subscription date by one day
              my_new_sub_date = "#{my_new_year}-#{my_new_month}-#{my_new_day}T00:00:00"
              my_data = {
              "date" => my_new_sub_date
                  }
              my_data = my_data.to_json
              reset_subscriber_date = HTTParty.post("https://api.rechargeapps.com/subscriptions/#{subscription_id}/set_next_charge_date", :headers => @my_change_charge_header, :body => my_data)
              puts "Changed Subscription Info, Details below:"
            puts reset_subscriber_date
          elsif month_30.include? next_month_name
            puts "We need to fix day 31 for this month since this month has only 30"
            if my_day_month == 31
              my_day_month = 30
              puts "New Day for Charge: #{my_day_month}"
              end
            my_new_sub_date = "#{my_new_year}-#{my_new_month}-#{my_day_month}T00:00:00"
            my_data = {
              "date" => my_new_sub_date
                 }
            my_data = my_data.to_json
            reset_subscriber_date = HTTParty.post("https://api.rechargeapps.com/subscriptions/#{subscription_id}/set_next_charge_date", :headers => @my_change_charge_header, :body => my_data)
            puts "Changed Subscription Info, Details below:"
            puts reset_subscriber_date
          else
            puts "we need to fix days 29-31 since Feb has only 28 and eff leap year"
            if my_day_month > 28
              my_day_month = 28
              puts "New Day for Charge in Feb: #{my_day_month}"
            end
            my_new_sub_date = "#{my_new_year}-#{my_new_month}-#{my_day_month}T00:00:00"
            my_data = {
              "date" => my_new_sub_date
                }
            my_data = my_data.to_json
            reset_subscriber_date = HTTParty.post("https://api.rechargeapps.com/subscriptions/#{subscription_id}/set_next_charge_date", :headers => @my_change_charge_header, :body => my_data)
            puts "Changed Subscription Info, Details below:"
            puts reset_subscriber_date
        end
          else
            #we can't skip the month because it is next month
            puts "Sorry We Can't Skip next month as it is next month"
          end




        end
        puts ""
        end


      end
      puts "Done with skipping this subscription, #{subscription_id}"
  end
end



end
