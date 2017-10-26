class RemoveCustomerId < ActiveRecord::Migration[5.1]
  
  def up
    remove_column :customer_alt_product, :customer_id, :string
  end

  def down
    add_column :customer_alt_product, :customer_id, :string

  end

end
