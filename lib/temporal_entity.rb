require_relative "./temporal_entity/schema"

module TemporalEntity
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def temporal(&block)
      @temporal_schema ||= Schema.new(self)

      @temporal_schema.instance_eval(&block)
      @temporal_schema.apply
    end

    def temporal_schema
      @temporal_schema
    end
  end
end
