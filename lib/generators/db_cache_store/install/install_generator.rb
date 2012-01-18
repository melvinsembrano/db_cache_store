module DbCacheStore
  module Generators
    class InstallGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('../templates', __FILE__)

      def generate_migration
        copy_file "migration.rb", "db/migrate/#{DateTime.now.strftime("%Y%m%d%H%M%S")}_create_db_caches.rb"
      end
    end
  end
end
