module TemporalEntity
  class Association
    class << self
      def inherited(subclass)
        subclass.class_eval do
          const_set("Record", Class.new(ActiveRecord::Base) {
            attribute :valid_at, :datetime
          })
        end
      end

      def left(entity_class_name)
        const_get("Record").class_eval do
          belongs_to :left, class_name: "#{entity_class_name}::Record"
        end
      end

      def right(entity_class_name)
        const_get("Record").class_eval do
          belongs_to :right, class_name: "#{entity_class_name}::Record"
        end
      end
    end
  end
end
