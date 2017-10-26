class CustomerAltProduct < ActiveRecord::Migration[5.1]
  def up
    create_table :customer_alt_product do |t|
      t.string :shopify_id
      t.string :customer_id
      t.string :subscription_id
      t.string :alt_product_id
      t.string :alt_variant_id
      t.string :alt_product_title
      t.datetime :date_switched
      
    end
    add_index :customer_alt_product, :shopify_id 
    add_index :customer_alt_product, :subscription_id 


  end

  def down
    remove_index :customer_alt_product, :shopify_id 
    remove_index :customer_alt_product, :subscription_id 
    drop_table :customer_alt_product
  end


end
