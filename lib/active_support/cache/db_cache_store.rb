# DbCacheStore
# melvinsembrano@gmail.com
#
#
module ActiveSupport
  module Cache
    class DbCacheStore < Store
      
      def initialize(options = nil)
        @klass = DbCache
        super(options)
      end

      def clear(options=nil)
        @klass.delete_all
      end

      def count
        @klass.count
      end

      def keys(options = {})
        options.symbolize_keys!
       @klass.all.select {|c| !c.expired? || options[:include_expires]}.collect {|c| c.key.to_sym}
      end

      def cleanup
        l = 0
        @klass.all.each do |c|
          entry = c.entry
          if entry.expired?
            c.delete
            l += 1
          end
        end
        l
      end

      protected

      def write_entry(key, entry, options)
        data = @klass.find_or_create_by_key(key)
        data.value = entry
        data.save
      end

      def read_entry(key, options)
        data = @klass.find_by_key(key)
        entry = nil
        unless data.nil?
          entry = data.entry
          if entry.expired?
            data.delete
            entry = nil
          end
        end
        entry
      end

      def delete_entry(key, options)
        data = @klass.find_by_key(key)
        if data
          data.delete
        else
          false
        end
      end
      
    end
  end
end

class DbCache < ActiveRecord::Base
  def entry
    YAML.load(value) unless value.nil?
  end

  def expired?
    entry && entry.expired?
  end
end
