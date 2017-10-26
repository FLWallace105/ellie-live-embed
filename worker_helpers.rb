#worker_helpers.rb


module FixMonth
  
  def unskip_month_recharge(subscriber_month)
    puts subscriber_month.inspect
    
    subscriber_month = subscriber_month << 1
    my_new_year = subscriber_month.strftime("%Y")
    my_new_month = subscriber_month.strftime("%m")
    my_new_day = subscriber_month.strftime("%d")

    my_new_date = "#{my_new_year}-#{my_new_month}-#{my_new_day}T00:00:00"
    puts my_new_date
    
    local_data = {
             "date" => my_new_date
                }
    local_data = local_data.to_json
    puts local_data
    return local_data
    
  end

  def reset_charge_date_post(subscriber_id, headers, body)
    reset_subscriber_date = HTTParty.post("https://api.rechargeapps.com/subscriptions/#{subscriber_id}/set_next_charge_date", :headers => headers, :body => body)
    puts "Changed Subscription Info, Details below:"
    puts reset_subscriber_date
    #puts "#{subscriber_id}, #{headers}, #{body}"

  end

  def request_customer_email(shopify_id, headers)
    get_customer_email = HTTParty.get("https://api.rechargeapps.com/customers?shopify_customer_id=#{shopify_id}", :headers => headers)
     customer_email = get_customer_email.parsed_response
     cust_email = customer_email['customers']
     #puts cust_email.inspect
     #puts cust_email[0]['email']
     my_customer_email = cust_email[0]['email']
     #puts "My customer_email = #{my_customer_email}" 
     return my_customer_email

  end

  def request_subscriber_id(shopify_id, headers, ellie_3pack_id, monthly_box_id, three_month_id)
    my_subscription_id = ''
    subscription_id_array = Array.new
    orig_sub_date = ''
     get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}&status=ACTIVE", :headers => headers)
    subscriber_info = get_sub_info.parsed_response
    #puts subscriber_info.inspect
    subscriptions = get_sub_info.parsed_response['subscriptions']
    #puts subscriptions.inspect
    subscriptions.each do |subs|
      puts "-------------"
        puts subs.inspect
      puts "-------------"
        shopify_product_id = subs['shopify_product_id']
        product_title = subs['product_title']
        #ck for shopify_product_id equal to monthly box or ellie_3pack ids, or check for product_title having "box in it"
        if (shopify_product_id.to_i  == ellie_3pack_id.to_i || shopify_product_id.to_i  == monthly_box_id.to_i || product_title =~ /\sbox/i || shopify_product_id.to_i == three_month_id.to_i) 
          #puts "Subscription scheduled at: #{subs['next_charge_scheduled_at']}"
          #=~ /\A3\sMonths/i || subs['product_title'] =~ /box/i
          puts "*****************************"
          puts "#{subs['id']}, #{subs['product_title']}, #{subs['status']} "
          puts "*****************************"
          #orig_sub_date = subs['next_charge_scheduled_at']
          my_subscription_id = subs['id'] 
          subscription_id_array.push(my_subscription_id)       
          end
      end
    #my_subscriber_data = {'my_subscription_id' => my_subscription_id, 'orig_sub_date' => orig_sub_date }
    return subscription_id_array
  end

  def skip_to_next_month(subscription_id, my_sub_date, headers)
      my_next_month = my_sub_date >> 1
      my_new_year = my_next_month.strftime("%Y")
      my_new_month = my_next_month.strftime("%m")
      my_new_day = my_next_month.strftime("%d")
      my_new_sub_date = "#{my_new_year}-#{my_new_month}-#{my_new_day}T00:00:00"
      my_data = {
            "date" => my_new_sub_date
                }
      my_data = my_data.to_json
      #puts my_data
      reset_subscriber_date = HTTParty.post("https://api.rechargeapps.com/subscriptions/#{subscription_id}/set_next_charge_date", :headers => headers, :body => my_data)
      check_recharge_limits(reset_subscriber_date)
      puts "Changed Subscription Info, Details below:"
      puts reset_subscriber_date

  end  

  def check_change_date_ok(current_month, my_subscription_id, orig_sub_date, new_date, headers)
      my_sub_date = DateTime.parse(orig_sub_date)
      #proposed_date = DateTime.parse(new_date)
      proposed_date = DateTime.strptime(new_date, "%m-%d-%Y")
      proposed_month = proposed_date.strftime("%B")
      if proposed_month == current_month
        puts "changing shipment date in this month"
        #make sure change day of month > today day of the month
        today_date = Date.today.strftime("%e").to_i
        proposed_day = proposed_date.strftime("%e").to_i
        puts "today_date = #{today_date} and proposed_day = #{proposed_day}"
        my_temp_stuff = proposed_day - today_date
        puts "my_temp_stuff = #{my_temp_stuff}"
        if my_temp_stuff > 0
          puts "Can change date, it is later than today"
          new_year = proposed_date.strftime("%Y")
          new_month = proposed_date.strftime("%m")
          new_day = proposed_date.strftime("%d")
          my_new_sub_date = "#{new_year}-#{new_month}-#{new_day}T00:00:00"
          body = {
                 "date" => my_new_sub_date
                     }
          body = body.to_json
          reset_charge_date_post(my_subscription_id, headers, body)

        else
          puts "You can't change the charge/shipment date to one in the past or today, must be in the future"
        end
      else
        puts "The proposed_month date change is #{proposed_month} which is not this month: #{current_month}"
        puts "Cant do anything"
      end

  end


  def request_recharge_id(shopify_id, my_get_header)
      get_info = HTTParty.get("https://api.rechargeapps.com/customers?shopify_customer_id=#{shopify_id}", :headers => my_get_header)
      my_info = get_info.parsed_response
      puts my_info.inspect
      cust_id = my_info['customers'][0]['id']
      puts cust_id.inspect
      sleep 3
      return cust_id
  end

  def request_address_id(cust_id, my_get_header)
    customer_addresses = HTTParty.get("https://api.rechargeapps.com/customers/#{cust_id}/addresses", :headers => my_get_header)
    my_addresses = customer_addresses.parsed_response
    puts my_addresses.inspect
    address_id = my_addresses['addresses'][0]['id']
    puts "address_id = #{address_id}"
    puts "Must sleep 3 seconds"
    sleep 3
    return address_id
  end

  
  def submit_upsell_request(cust_id, address_id, shopify_id, shopify_variant_id, my_product_id, product_title, true_price, my_get_header, my_change_charge_header, line_item_properties)
    puts "First checking to see if we have a subscription created this month"
    puts "If created this month, we cannot add on as it creates a new MAIN subscription"
    puts "Subsequent months are OK though."
    # Ck for: active subscription, created_at is not this month
    #Get first day of current month
    my_today = Date.today.beginning_of_month

    add_onetime_subscription = false
    active_subscriptions = false
    all_subscriptions_customer = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => my_get_header)
    check_recharge_limits(all_subscriptions_customer)
    all_subscriptions_customer.parsed_response['subscriptions'].each do |subs|
      #puts subs.inspect
      status = subs['status']
      created_at = subs['created_at']
      my_created_at = DateTime.strptime(created_at, '%Y-%m-%dT%H:%M:%S')
      if status != "CANCELLED" && status != "ONETIME"
        active_subscriptions = true
        puts "--------------"
        puts subs.inspect
        puts "-------------"
        #puts "created_at date is #{created_at} and first day current month is #{my_today.inspect}"
        if my_today > my_created_at
          puts "created_at date is #{created_at} and first day current month is #{my_today.inspect}"
          puts "We can now add a subscription because it was not created this month"
          add_onetime_subscription = true
          end
        end

      end

    if add_onetime_subscription
      #add the one time subscription
      puts "Adding upsell"
      my_charge_date = Date.today
      local_charge_date = my_charge_date.strftime('%Y-%m-%dT%H:%M:%S')
      quantity = 1
      data_send_to_recharge = {"address_id" => address_id, "next_charge_scheduled_at" => local_charge_date, "product_title" => product_title, "shopify_product_id" => my_product_id,  "price" => true_price, "quantity" => "#{quantity}", "shopify_variant_id" => shopify_variant_id, "order_interval_unit" => "month", "order_interval_frequency" => "1", "charge_interval_frequency" => "1", "number_charges_until_expiration" => "1", "properties" => line_item_properties }.to_json
          
      puts data_send_to_recharge
      puts "Submitting order as a new upsell subscription"
      send_upsell_to_recharge = HTTParty.post("https://api.rechargeapps.com/subscriptions", :headers => my_change_charge_header, :body => data_send_to_recharge)
      puts send_upsell_to_recharge.inspect

    else
      puts "We could NOT ADD A SUBSCRIPTION because either no active subscriptions or subscription was created this month."
      puts "Active Subscriptions = #{active_subscriptions}, any subscription not created this month = #{add_onetime_subscription}"
    end


  end




  def check_for_duplicate_subscription(cust_id, address_id, shopify_id, shopify_variant_id, my_product_id, product_title, true_price, my_get_header, my_change_charge_header, line_item_properties)
    puts "Checking for duplicate orders ..."
    all_orders_customer = HTTParty.get("https://api.rechargeapps.com/orders?customer_id=#{cust_id}", :headers => my_get_header)

    check_recharge_limits(all_orders_customer)

    #puts all_orders_customer.inspect
    successful_orders = false
    
    puts "Checking for duplicates ..."
    
    current_month = Date.today.strftime("%B")
    last_day_current_month = Date.today.end_of_month
    day_current_month = Date.today + 1
        
    quantity = 1
    puts "We want to avoid duplicate orders for ... #{product_title}, variant_id #{shopify_variant_id}"
    #puts all_orders_customer.parsed_response['orders'].inspect

    all_orders_customer.parsed_response['orders'].each do |mysub|
        #puts mysub.inspect
        puts "Checking an order ..."
        #puts "------------------"
        local_variant_id = mysub['line_items'][0]['shopify_variant_id']
        local_status = mysub['status']
        #local_sku = mysub['sku']
        local_product_title = mysub['line_items'][0]['title']
        
        local_charge_date = mysub['scheduled_at']
        local_subscription_id = mysub['line_items'][0]['subscription_id']
        
        local_scheduled_date = DateTime.strptime(local_charge_date, '%Y-%m-%dT%H:%M:%S')
        
        
        #puts "Local Title = #{local_product_title}"
        if local_status == "QUEUED" && ( local_product_title =~ /\d\sMonth/i || local_product_title =~ /\sbox/i) && local_scheduled_date <= last_day_current_month && local_scheduled_date >= day_current_month
          puts "variant_id = #{local_variant_id}, status=#{local_status}, local_title=#{local_product_title}, scheduled_at=#{local_charge_date}"
          #now check for duplicate orders
          puts "Subscription_ID = #{local_subscription_id}"

          puts "OK, submitting order"
          data_send_to_recharge = {"address_id" => address_id, "next_charge_scheduled_at" => local_charge_date, "product_title" => product_title, "shopify_product_id" => my_product_id,  "price" => true_price, "quantity" => "#{quantity}", "shopify_variant_id" => shopify_variant_id, "order_interval_unit" => "month", "order_interval_frequency" => "1", "charge_interval_frequency" => "1", "number_charges_until_expiration" => "1", "properties" => line_item_properties }.to_json
          
          puts data_send_to_recharge
          puts "Submitting order as a new upsell subscription"
          send_upsell_to_recharge = HTTParty.post("https://api.rechargeapps.com/subscriptions", :headers => my_change_charge_header, :body => data_send_to_recharge)
          puts send_upsell_to_recharge.inspect
          successful_orders = true
          return
        end
      end

  
  
  puts "We are done processing 3 Month orders"

        if !successful_orders
          puts "We have no open orders associated with a 3 Monthly Subscription, checking for Monthly Subscriptions"
          all_subscriptions_customer = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => my_get_header)
          check_recharge_limits(all_subscriptions_customer)
          #puts all_subscriptions_customer.parsed_response.inspect
          all_subscriptions_customer.parsed_response['subscriptions'].each do |subs|
              
              
              #next_charge_scheduled_at = mysub['next_charge_scheduled_at']
              status = subs['status']
              local_product_title = subs['product_title']
              next_charge_scheduled_at = subs['next_charge_scheduled_at']
              
              puts subs.inspect
              #local_scheduled_date = DateTime.strptime(next_charge_scheduled_at, '%Y-%m-%dT%H:%M:%S')
              if status == "ACTIVE" && local_product_title =~ /\sbox/i
                puts "----------------"
                puts "status = #{status}, title = #{local_product_title}"
                puts "----------------"
                if !next_charge_scheduled_at.nil?
                    my_next_charge = DateTime.strptime(next_charge_scheduled_at, '%Y-%m-%dT%H:%M:%S')
                    puts "Checking date to see if its this month and not already past time"
                    if my_next_charge >= day_current_month && my_next_charge <= last_day_current_month
                      puts "next charge date is this month and is valid: #{next_charge_scheduled_at}"
                      
                      puts "OK, submitting order"
                      data_send_to_recharge = {"address_id" => address_id, "next_charge_scheduled_at" => next_charge_scheduled_at, "product_title" => product_title, "shopify_product_id" => my_product_id,  "price" => true_price, "quantity" => "#{quantity}", "shopify_variant_id" => shopify_variant_id, "order_interval_unit" => "month", "order_interval_frequency" => "1", "charge_interval_frequency" => "1", "number_charges_until_expiration" => "1", "properties" => line_item_properties }.to_json
          
                      puts data_send_to_recharge
                      puts "Submitting order as a new upsell subscription"
                      send_upsell_to_recharge = HTTParty.post("https://api.rechargeapps.com/subscriptions", :headers => my_change_charge_header, :body => data_send_to_recharge)
                      puts send_upsell_to_recharge.inspect
                      return


                      end
                end
            end

          end
        
        end
        
          
end

  def check_recharge_limits(api_info)
      my_api_info = api_info.response['x-recharge-limit']
      api_array = my_api_info.split('/')    
      my_numerator = api_array[0].to_i
      my_denominator = api_array[1].to_i
      api_percentage_used = my_numerator/my_denominator.to_f
      puts "API Call percentage used is #{api_percentage_used.round(2)}"
      if api_percentage_used > 0.6
        puts "Must sleep 8 seconds"
        sleep 8
        puts "done sleeping"
      end

  end

  def add_shopify_order(myemail, myaccessories1, myaccessories2, myleggings, mysportsbra, mytops, myfirstname, mylastname, myaddress1, myaddress2, myphone, mycity, mystate, myzip, apikey, password, shopname, prod_id, mysku, influencer_tag, shop_wait, product_title)
    puts "Adding Order for Influencer -- "
    puts "prod_id=#{prod_id}"
    my_order = {
             "order": {
              "email": myemail, 
              "send_receipt": true,
              "send_fulfillment_receipt": true,
              "tags": influencer_tag,
              "line_items": [
              {
              "product_id": prod_id,
              "quantity": 1,
              "price": 0.00,
              "title": product_title,
              "sku": mysku, 
              "properties": [
                    
                    {
                        "name": "leggings",
                        "value": myleggings
                    },
                    {
                        "name": "main-product",
                        "value": "true"
                    },                    
                    {
                        "name": "tops",
                        "value": mytops
                    },
                    {
                        "name": "sports-jacket",
                        "value": mytops 
                    }
                ]
              }
            ], 
            "customer": {
      "first_name": myfirstname,
      "last_name": mylastname,
      "email": myemail
    },
    "billing_address": {
      "first_name": myfirstname,
      "last_name": mylastname,
      "address1": myaddress1,
      "address2": myaddress2,
      "phone": myphone,
      "city": mycity,
      "province": mystate,
      "country": "United States",
      "zip": myzip
    },
    "shipping_address": {
      "first_name": myfirstname,
      "last_name": mylastname,
      "address1": myaddress1,
      "address2": myaddress2,
      "phone": myphone,
      "city": mycity,
      "province": mystate,
      "country": "United States",
      "zip": myzip
    }
    
            
            }
          }
      
      #puts my_order
      my_url = "https://#{apikey}:#{password}@#{shopname}.myshopify.com/admin"
      my_addon = "/orders.json"
      total_url = my_url + my_addon
      puts total_url
      response = HTTParty.post(total_url, :body => my_order)
      puts response
      puts "Done adding orders, now checking for shopify call limits:"
      headerinfo = ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
      check_shopify_call_limit(headerinfo, shop_wait)

  end

  def add_shopify_bottle_order(myemail, myprod, mysku, myfirstname, mylastname, myaddress1, myaddress2, myphone, mycity, mystate, myzip, apikey, password, shopname, prod_id, influencer_tag, shop_wait)
    puts "Adding Order for Influencer -- "
    puts "prod_id=#{prod_id}"
    my_order = {
             "order": {
              "email": myemail, 
              "send_receipt": true,
              "send_fulfillment_receipt": true,
              "tags": influencer_tag,
              "line_items": [
              {
              "id": prod_id,
              "sku": mysku,
              "quantity": 1,
              "price": 0.00,
              "title": myprod,
              "name": myprod,
              }
            ], 
            "customer": {
      "first_name": myfirstname,
      "last_name": mylastname,
      "email": myemail
    },
    "billing_address": {
      "first_name": myfirstname,
      "last_name": mylastname,
      "address1": myaddress1,
      "address2": myaddress2,
      "phone": myphone,
      "city": mycity,
      "province": mystate,
      "country": "United States",
      "zip": myzip
    },
    "shipping_address": {
      "first_name": myfirstname,
      "last_name": mylastname,
      "address1": myaddress1,
      "address2": myaddress2,
      "phone": myphone,
      "city": mycity,
      "province": mystate,
      "country": "United States",
      "zip": myzip
    }
    
            
            }
          }
      
      #puts my_order
      my_url = "https://#{apikey}:#{password}@#{shopname}.myshopify.com/admin"
      my_addon = "/orders.json"
      total_url = my_url + my_addon
      puts total_url
      response = HTTParty.post(total_url, :body => my_order)
      puts response
      puts "Done adding orders, now checking for shopify call limits:"
      headerinfo = ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
      check_shopify_call_limit(headerinfo, shop_wait)

  end



  def tag_shopify_influencer(shopify_id, new_tags, apikey, password, shopname, shop_wait)
    my_customer_tag = {
             "customer":  {
             "id": shopify_id,
              
              "tags": new_tags,
              "note": "Influencer done through API"
              }
            }
      my_url = "https://#{apikey}:#{password}@#{shopname}.myshopify.com/admin"
      my_addon = "/customers/#{shopify_id}.json"
      total_url = my_url + my_addon
      puts "Tagging Customer"
      puts total_url
      puts my_customer_tag
      tag_response = HTTParty.put(total_url, :body => my_customer_tag)
      puts tag_response
      #Get header response
      headerinfo = ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
      check_shopify_call_limit(headerinfo, shop_wait)
      puts "Done adding customer tags"

  end

  def create_shopify_influencer_cust(firstname, lastname, email, phone, address1, address2, city, state, zip, apikey, password, shopname, shop_wait)
    #POST /admin/customers.json
    my_new_customer = {
            "customer": {
            "first_name": firstname,
            "last_name": lastname,
            "email": email,
            "phone": phone,
            
            "addresses": [
            {
              "address1": address1,
              "address2": address2,
              "city": city,
              "province": state,
              "phone": phone,
              "zip": zip,
              "last_name": lastname,
              "first_name": firstname,
              "country": "United States"
            }
          ]
    
        }
      }
  
  my_url = "https://#{apikey}:#{password}@#{shopname}.myshopify.com/admin"
  my_addon = "/customers.json"
  total_url = my_url + my_addon
  puts "Adding new influencer"
  puts total_url
  puts my_new_customer
  customer_response = HTTParty.post(total_url, :body => my_new_customer)
  puts customer_response
  puts "Done adding new influencer, now checking shopify call limits:"
  headerinfo = ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
  check_shopify_call_limit(headerinfo, shop_wait)
  customer_id = customer_response['customer']['id']
  return customer_id


end

def check_duplicate_orders(shopify_id, apikey, password, shopname, influencer_product, shop_wait)
  #GET /admin/customers/#{id}/orders.json
  my_url = "https://#{apikey}:#{password}@#{shopname}.myshopify.com/admin"
  my_addon = "/customers/#{shopify_id}/orders.json"
  total_url = my_url + my_addon
  puts total_url
  puts "Checking for duplicate orders"
  customer_orders = HTTParty.get(total_url)
  headerinfo = ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
  check_shopify_call_limit(headerinfo, shop_wait)
  #puts customer_orders
  #Get today's date
  my_today = Date.today
  my_current_year = my_today.strftime('%Y')
  my_current_month = my_today.strftime('%B')
  my_current = "#{my_current_month}-#{my_current_year}"
  create_new_order = true

  puts "-----------------------"
  my_orders = customer_orders['orders']
  my_orders.each do |orderinfo|
      puts "----------------"
      #puts JSON.pretty_generate(orderinfo, {:indent => "\t"})
      created_at = orderinfo['created_at']
      order_name = orderinfo['name']
      order_created_at = DateTime.strptime(created_at, '%Y-%m-%dT%H:%M:%S')
      order_year = order_created_at.strftime('%Y')
      order_month = order_created_at.strftime('%B')
      order_current = "#{order_month}-#{order_year}"
      puts "Information for order #{order_name}:"
      puts "Order Created -> #{order_current}, Now => #{my_current}"
      order_title = orderinfo['line_items'][0]['title']
      puts "order_title = #{order_title}, checking against product #{influencer_product}"
      if order_current == my_current && order_title == influencer_product
        create_new_order = false
      end
      puts "================"
    end
return create_new_order

end

def check_shopify_call_limit(headerinfo, shop_wait)
  puts "raw Shopify call limit info: #{headerinfo}"
  header_data = headerinfo.split('/')
  my_numerator = header_data[0].to_i
  my_denominator = header_data[1].to_i
  percentage = (my_numerator/my_denominator.to_f).round(2)
  puts "Used #{percentage} of Shopify call limits"
  if percentage >= 0.7
    puts "Sleeping #{shop_wait}"
    sleep shop_wait
  end

end

def check_next_charge_this_month(scheduled_at)
  my_scheduled_at = DateTime.strptime(scheduled_at, "%Y-%m-%dT%H:%M:%S")
  puts "my_scheduled_at = #{scheduled_at}, #{my_scheduled_at.inspect}"
  my_now = Date.today
  my_begin_month = my_now.beginning_of_month
  my_end_month = my_now.end_of_month
  if (my_scheduled_at <= my_end_month) && (my_scheduled_at >= my_begin_month)
    puts "can skip this sub"
    return true
  else
    puts "can't skip this sub, next charge date is the in the next month"
    return false
  end
end

def skip_this_sub(subelement, my_change_charge_header, my_get_header, shopify_customer_id, uri, reason)
  puts "Now skipping this sub"
  #POST /subscriptions/<subscription_id>/set_next_charge_date
  my_now = Date.today
  my_now_str = my_now.strftime("%Y-%m-%d")
  my_end_month = my_now.end_of_month
  my_end_month_str = my_end_month.strftime("%Y-%m-%d")
  my_next_month = my_now >> 1
  my_next_month_str = my_next_month.strftime("%Y-%m-%d")
  body = { "date" => my_next_month_str }.to_json

  myuri = URI.parse(uri)
  my_conn =  PG.connect(myuri.hostname, myuri.port, nil, nil, myuri.path[1..-1], myuri.user, myuri.password)
  my_insert = "insert into customer_skips (shopify_id, subscription_id, charge_id, skipped_on, skipped_to, skip_status, skip_reason) values ($1, $2, $3, $4, $5, $6, $7)"
  my_conn.prepare('statement1', "#{my_insert}") 




  reset_subscriber_date = HTTParty.post("https://api.rechargeapps.com/subscriptions/#{subelement}/set_next_charge_date", :headers => my_change_charge_header, :body => body)
  puts reset_subscriber_date.inspect
  check_recharge_limits(reset_subscriber_date)
  #get charges for that subscription, skip the one this month
  #GET /charges?subscription_id=14562
  #GET /charges?date_min=2016-05-18&date_max=2016-06-18
  subscriber_charges = HTTParty.get("https://api.rechargeapps.com/charges?subscription_id=#{subelement}&date_min=#{my_now_str}&date_max=#{my_end_month_str}", :headers => my_get_header)
  check_recharge_limits(subscriber_charges)
  puts "Charge info for this subscription #{subelement} ==> #{subscriber_charges}"
  charge_info = subscriber_charges.parsed_response
  puts charge_info.inspect
  my_charge = charge_info['charges']
  my_charge_id = ""
  my_empty = []
  puts my_charge.inspect
  if my_charge.empty? 
    my_charge.each do |myc|
      puts "-------"
      puts myc.inspect
      my_charge_id = myc['id']
      #POST /charges/<charge_id>/skip
      puts "**********"
      puts "skipping charge for #{my_charge_id}"
      body = { "subscription_id": subelement }.to_json
      my_skip_charge = HTTParty.post("https://api.rechargeapps.com/charges/#{my_charge_id}/skip", :headers => my_change_charge_header, :body => body)
      puts my_skip_charge.inspect
      check_recharge_limits(my_skip_charge)
      
      puts "***********"
      puts "--------"
    end
    

  else
    puts "No charges queued to skip for this subscription: #{subscription_id}"
  end

  puts uri, shopify_customer_id, my_charge_id
  my_result = my_conn.exec_prepared('statement1', [shopify_customer_id, subelement, my_charge_id, my_now_str, my_next_month_str, true, reason])
  puts my_result.inspect

end

def get_customer_subscriptions(shopify_id, my_get_header, my_change_header, uri, my_id_hash, my_alt_prod_hash)
  get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => my_get_header)
  #puts get_sub_info.inspect
  my_sub_array = Array.new
  monthly_box_id = my_id_hash['monthly_box_id']
  ellie_threepack_id = my_id_hash['ellie_threepack_id']
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
        temp_hash = {"subscription_id" => temp_subscription_id, "product_id" => temp_product_id, "shopify_id" => shopify_id}
        my_sub_array.push(temp_hash)
      end

    puts "--------"
    end
  end
  puts "Done with subscription parsing!"

  
  if !my_sub_array.empty?
    puts "WE have the following subscriptions to change the next_charge_date and associated charges"
    my_sub_array.each do |subelement|
    puts "Changing subscription #{subelement.inspect} to reflect alternative product this month"
    
    update_sub_alternate_product(subelement, my_change_header, uri, my_id_hash, my_alt_prod_hash)
    end
  end

end

def update_sub_alternate_product(my_hash, my_change_header, uri, my_id_hash, my_alt_prod_hash)
  my_sub_id = my_hash['subscription_id']
  my_product_id = my_hash['product_id']
  my_shopify_id = my_hash['shopify_id']
  monthly_box_id = my_id_hash['monthly_box_id']
  ellie_threepack_id = my_id_hash['ellie_threepack_id']

  alt_monthly_box_title = my_alt_prod_hash['alt_monthly_box_title']
  alt_monthly_box_id = my_alt_prod_hash['alt_monthly_box_id']
  alt_monthly_box_variant_id = my_alt_prod_hash['alt_monthly_box_variant_id']
  alt_monthly_box_sku = my_alt_prod_hash['alt_monthly_box_sku']

  alt_ellie_3pack_id = my_alt_prod_hash['alt_ellie_3pack_id']
  alt_ellie_3pack_sku = my_alt_prod_hash['alt_ellie_3pack_sku']
  alt_ellie_3pack_title = my_alt_prod_hash['alt_ellie_3pack_title']
  alt_ellie_3pack_variant_id = my_alt_prod_hash['alt_ellie_3pack_variant_id']

  

  puts "Updating subscription #{my_sub_id}"
  
  myuri = URI.parse(uri)
  my_conn =  PG.connect(myuri.hostname, myuri.port, nil, nil, myuri.path[1..-1], myuri.user, myuri.password)
  my_insert = "insert into customer_alt_product (shopify_id, subscription_id, alt_product_id, alt_variant_id, alt_product_title, date_switched) values ($1, $2, $3, $4, $5, $6)"
  my_conn.prepare('statement1', "#{my_insert}") 



  body = {}
  body_as_hash = {}
  continue_update_sub = false
  if my_product_id == monthly_box_id
    body = {"product_title" => alt_monthly_box_title, "shopify_product_id" => alt_monthly_box_id, "shopify_variant_id" => alt_monthly_box_variant_id, sku => alt_monthly_box_sku}
    body_as_hash = body
    body = body.to_json
    continue_update_sub = true
  elsif my_product_id == ellie_threepack_id
    body = {"product_title" => alt_ellie_3pack_title, "shopify_product_id" => alt_ellie_3pack_id, "shopify_variant_id" => alt_ellie_3pack_variant_id, "sku" => alt_ellie_3pack_sku}
    body_as_hash = body
    body = body.to_json
    continue_update_sub = true
  else
    puts "Neither a Monthly Box nor Ellie 3- Pack product: #{my_sub_id} thus we can do nothing"
  end

  if continue_update_sub
    puts "Updating Subscription properties"
    puts body_as_hash.inspect
    #puts my_change_header.inspect
    #puts body.inspect
    #PUT /subscriptions/<subscription_id>
    my_update_sub = HTTParty.put("https://api.rechargeapps.com/subscriptions/#{my_sub_id}", :headers => my_change_header, :body => body)
    puts my_update_sub.inspect
    check_recharge_limits(my_update_sub)
    #insert into DB here
    alt_product_id = body_as_hash['shopify_product_id']
    alt_variant_id = body_as_hash['shopify_variant_id']
    alt_product_title = body_as_hash['product_title']
    my_now = Date.today
    my_now_str = my_now.strftime("%Y-%m-%d")

    my_result = my_conn.exec_prepared('statement1', [my_shopify_id, my_sub_id, alt_product_id, alt_variant_id, alt_product_title, my_now_str])
    puts my_result.inspect


  else
    puts "We can't update the sub with an alternate product as the product type is wrong."
  end



end

end