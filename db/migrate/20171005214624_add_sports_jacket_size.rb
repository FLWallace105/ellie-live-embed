class AddSportsJacketSize < ActiveRecord::Migration[5.1]
  def up
    add_column :influencers, :sports_jacket_size, :string
  end

  def down
    remove_column :influencers, :sports_jacket_size, :string

  end
end
