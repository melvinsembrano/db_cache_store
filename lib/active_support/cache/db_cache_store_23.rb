require 'zlib'

module ActiveSupport
  module Cache
    class DbCacheStore23 < DbCacheStore

      def initialize(options = nil)
        @klass = DbCache

      end

      def write(key, value, options = nil)
        options = merged_options(options)
        entry = Entry.new(value, options)
        write_entry(namespaced_key(name, options), entry, options)

      end

      def read(key, options = nil)
        options = merged_options(options)
        key = namespaced_key(name, options)
        entry = read_entry(key, options)
        if entry
          if entry.expired?
            delete_entry(key, options)
            payload[:hit] = false if payload
            nil
          else
            payload[:hit] = true if payload
            entry.value
          end
        else
          payload[:hit] = false if payload
          nil
        end
      end

      def delete(key, options = nil)
        options = merged_options(options)
        delete_entry(namespaced_key(name, options), options)
      end

    # Entry that is put into caches. It supports expiration time on entries and can compress values
    # to save space in the cache.
    class Entry
      attr_reader :created_at, :expires_in

      DEFAULT_COMPRESS_LIMIT = 16.kilobytes

      class << self
        # Create an entry with internal attributes set. This method is intended to be
        # used by implementations that store cache entries in a native format instead
        # of as serialized Ruby objects.
        def create (raw_value, created_at, options = {})
          entry = new(nil)
          entry.instance_variable_set(:@value, raw_value)
          entry.instance_variable_set(:@created_at, created_at.to_f)
          entry.instance_variable_set(:@compressed, !!options[:compressed])
          entry.instance_variable_set(:@expires_in, options[:expires_in])
          entry
        end
      end

      # Create a new cache entry for the specified value. Options supported are
      # +:compress+, +:compress_threshold+, and +:expires_in+.
      def initialize(value, options = {})
        @compressed = false
        @expires_in = options[:expires_in]
        @expires_in = @expires_in.to_f if @expires_in
        @created_at = Time.now.to_f
        if value
          if should_compress?(value, options)
            @value = Zlib::Deflate.deflate(Marshal.dump(value))
            @compressed = true
          else
            @value = value
          end
        else
          @value = nil
        end
      end

      # Get the raw value. This value may be serialized and compressed.
      def raw_value
        @value
      end

      # Get the value stored in the cache.
      def value
        if @value
          val = compressed? ? Marshal.load(Zlib::Inflate.inflate(@value)) : @value
          unless val.frozen?
            val.freeze rescue nil
          end
          val
        end
      end

      def compressed?
        @compressed
      end

      # Check if the entry is expired. The +expires_in+ parameter can override the
      # value set when the entry was created.
      def expired?
        @expires_in && @created_at + @expires_in <= Time.now.to_f
      end

      # Set a new time when the entry will expire.
      def expires_at=(time)
        if time
          @expires_in = time.to_f - @created_at
        else
          @expires_in = nil
        end
      end

      # Seconds since the epoch when the entry will expire.
      def expires_at
        @expires_in ? @created_at + @expires_in : nil
      end

      # Returns the size of the cached value. This could be less than value.size
      # if the data is compressed.
      def size
        if @value.nil?
          0
        elsif @value.respond_to?(:bytesize)
          @value.bytesize
        else
          Marshal.dump(@value).bytesize
        end
      end

      private
        def should_compress?(value, options)
          if options[:compress] && value
            unless value.is_a?(Numeric)
              compress_threshold = options[:compress_threshold] || DEFAULT_COMPRESS_LIMIT
              serialized_value = value.is_a?(String) ? value : Marshal.dump(value)
              return true if serialized_value.size >= compress_threshold
            end
          end
          false
        end
    end

    private

      def merged_options(call_options) # :nodoc:
        if call_options
          options.merge(call_options)
        else
          options.dup
        end
      end

      # Expand key to be a consistent string value. Invoke +cache_key+ if
      # object responds to +cache_key+. Otherwise, to_param method will be
      # called. If the key is a Hash, then keys will be sorted alphabetically.
      def expanded_key(key) # :nodoc:
        return key.cache_key.to_s if key.respond_to?(:cache_key)

        case key
        when Array
          if key.size > 1
            key = key.collect{|element| expanded_key(element)}
          else
            key = key.first
          end
        when Hash
          key = key.sort_by { |k,_| k.to_s }.collect{|k,v| "#{k}=#{v}"}
        end

        key.to_param
      end

      def namespaced_key(key, options)
        key = expanded_key(key)
        namespace = options[:namespace] if options
        prefix = namespace.is_a?(Proc) ? namespace.call : namespace
        key = "#{prefix}:#{key}" if prefix
        key
      end

    end
  end
end
