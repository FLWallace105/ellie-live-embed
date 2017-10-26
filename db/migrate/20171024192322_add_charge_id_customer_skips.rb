class AddChargeIdCustomerSkips < ActiveRecord::Migration[5.1]
  def up 
  
    add_column :customer_skips, :charge_id, :string
  end

  def down
    remove_column :customer_skips, :charge_id, :string
  end
end
