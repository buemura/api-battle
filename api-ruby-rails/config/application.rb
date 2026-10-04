require_relative "boot"

require "rails"
require "active_record/railtie"
require "action_controller/railtie"

Bundler.require(*Rails.groups)

module ApiBattle
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true
    config.eager_load = true

    # Stateless JSON API: no cookies, sessions or encrypted data, so an
    # ephemeral key is fine when none is provided.
    config.secret_key_base = ENV.fetch("SECRET_KEY_BASE") { SecureRandom.hex(64) }

    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc
    # The schema is owned by db/init.sql; never dump or check migrations.
    config.active_record.dump_schema_after_migration = false
    config.active_record.migration_error = false

    config.logger = ActiveSupport::Logger.new($stdout).tap { |l| l.formatter = ::Logger::Formatter.new }
    config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "warn")

    # Render every error as JSON from ApplicationController instead of the
    # HTML debug pages.
    config.consider_all_requests_local = false
    config.action_dispatch.show_exceptions = :none
  end
end
