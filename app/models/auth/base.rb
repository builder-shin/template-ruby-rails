# frozen_string_literal: true

module Auth
  class Base < ApplicationRecord
    self.abstract_class = true

    # All Auth models are read-only (FDW tables)
    def readonly?
      true
    end

    # Prevent accidental writes at instance level
    before_create { raise ActiveRecord::ReadOnlyRecord, "Auth models are read-only" }
    before_update { raise ActiveRecord::ReadOnlyRecord, "Auth models are read-only" }
    before_destroy { raise ActiveRecord::ReadOnlyRecord, "Auth models are read-only" }

    # Prevent accidental writes at class level
    class << self
      def update_all(*)
        raise ActiveRecord::ReadOnlyRecord, "Auth models are read-only"
      end

      def delete_all(*)
        raise ActiveRecord::ReadOnlyRecord, "Auth models are read-only"
      end

      def destroy_all(*)
        raise ActiveRecord::ReadOnlyRecord, "Auth models are read-only"
      end

      def delete(*)
        raise ActiveRecord::ReadOnlyRecord, "Auth models are read-only"
      end

      def destroy(*)
        raise ActiveRecord::ReadOnlyRecord, "Auth models are read-only"
      end
    end

    # Prevent update_columns bypass
    def update_columns(*)
      raise ActiveRecord::ReadOnlyRecord, "Auth models are read-only"
    end

    # Prevent update_attribute bypass
    def update_attribute(*)
      raise ActiveRecord::ReadOnlyRecord, "Auth models are read-only"
    end

    # Prevent toggle! bypass
    def toggle!(*)
      raise ActiveRecord::ReadOnlyRecord, "Auth models are read-only"
    end

    # Prevent increment!/decrement! bypass
    def increment!(*)
      raise ActiveRecord::ReadOnlyRecord, "Auth models are read-only"
    end

    def decrement!(*)
      raise ActiveRecord::ReadOnlyRecord, "Auth models are read-only"
    end

    # Prevent touch bypass
    def touch(*)
      raise ActiveRecord::ReadOnlyRecord, "Auth models are read-only"
    end
  end
end
