class CreateCustomerSkips < ActiveRecord::Migration[5.1]
  
  def up 
    create_table :customer_skips do |t|
      t.string :shopify_id
      t.string :subscription_id
      t.datetime :skip_date
      t.string :skip_reason
      t.string :skip_status
    end
    add_index :customer_skips, :shopify_id 
    add_index :customer_skips, :subscription_id 

  end

  def down
    remove_index :customer_skips, :shopify_id 
    remove_index :customer_skips, :subscription_id 
    drop_table :customer_skips

  end


end
