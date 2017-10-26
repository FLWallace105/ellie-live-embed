class AddSuccessFieldCustomerAltProduct < ActiveRecord::Migration[5.1]
  
  def up
    add_column :customer_alt_product, :update_success, :boolean, :default => false
  end

  def down
    remove_column :customer_alt_product, :update_success, :boolean, :default => false

  end
end
