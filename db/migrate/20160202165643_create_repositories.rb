class CreateRepositories < ActiveRecord::Migration
  def change
    create_table :repositories do |t|

      t.string     :repos_url
      t.float      :bus_factor
      t.string     :bus_factor_string
      t.integer    :releases
      t.float      :refactoring
      t.integer    :prs
      t.datetime   :refactoring_created_at
      t.datetime   :refactoring_last_push
      t.integer    :stars
      t.integer    :watchers
      t.integer    :forks 

      t.timestamps null: false
    end
  end
end
