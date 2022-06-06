require "active_record"

module TemporalEntity
  class Attribute < ActiveRecord::Base
    class << self
      def inherited(subclass)
        subclass.class_eval do
          attribute :valid_at, :datetime
        end
      end
    end
  end
end
