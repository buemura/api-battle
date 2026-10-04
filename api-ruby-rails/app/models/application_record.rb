class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # The schema is owned by db/init.sql: `created_at` comes from the column
  # default (returned by INSERT ... RETURNING) and there is no `updated_at`.
  self.record_timestamps = false
end
