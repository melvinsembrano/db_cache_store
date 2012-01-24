class DbCache < ActiveRecord::Base
  def entry
    YAML.load(value) unless value.nil?
  end

  def expired?
    entry && entry.expired?
  end
end
