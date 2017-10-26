class ChangeCustomerSkipColumnNames < ActiveRecord::Migration[5.1]
  
  def up
    rename_column :customer_skips, :skip_date, :skipped_on
    add_column :customer_skips, :skipped_to, :datetime
  end
  
  def down
    rename_column :customer_skips, :skipped_on, :skip_date
    remove_column :customer_skips, :skipped_to, :datetime

  end
end
