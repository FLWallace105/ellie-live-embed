class ChangeCustomerSkipSkipStatus < ActiveRecord::Migration[5.1]
  
  def up
    change_column :customer_skips, :skip_status, 'boolean USING CAST(skip_status AS boolean)'
  end

  def down
    change_column :customer_skips, :skip_status, :string

  end


end
