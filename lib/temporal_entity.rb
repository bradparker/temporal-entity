require_relative "./temporal_entity/schema"
require_relative "./temporal_entity/relation"

module TemporalEntity
  def self.included(base)
    base.extend ClassMethods

    base.attribute :relative_time, :datetime
    base.after_initialize do
      self.relative_time ||= Time.current
    end
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

    def at_time(time)
      Relation.new(time, self)
    end
  end

  def at_time(time)
    self.class.at_time(time).find_by("#{self.class.primary_key}": public_send(self.class.primary_key)) ||
      dup.tap {|s| s.assign_attributes(relative_time: time) }
  end
end
