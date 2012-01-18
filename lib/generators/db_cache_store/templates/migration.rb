class CreateDbCaches < ActiveRecord::Migration
  def change
    create_table :db_caches do |t|
      t.string :key
      t.binary :value, :limit => 4294967295
      t.timestamp
    end
    add_index :db_caches, :key
  end
end
