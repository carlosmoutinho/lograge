require 'lograge/version'
require 'lograge/log_subscriber'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/string/inflections'
require 'active_support/ordered_options'

module Lograge
  mattr_accessor :logger

  # Custom options that will be appended to log line
  #
  # Currently supported formats are:
  #  - Hash
  #  - Any object that responds to call and returns a hash
  #
  mattr_writer :custom_options
  self.custom_options = nil

  mattr_writer :custom_prefixes
  self.custom_prefixes = nil

  def self.custom_options(event)
    if @@custom_options.respond_to?(:call)
      @@custom_options.call(event)
    else
      @@custom_options
    end
  end

  def self.custom_prefixes(event)
    if @@custom_prefixes.respond_to?(:call)
      @@custom_prefixes.call(event)
    else
      @@custom_prefixes
    end
  end

  def self.remove_existing_log_subscriptions
    ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
      case subscriber
      when ActionView::LogSubscriber
        unsubscribe(:action_view, subscriber)
      when ActionController::LogSubscriber
        unsubscribe(:action_controller, subscriber)
      end
    end
  end

  def self.unsubscribe(component, subscriber)
    events = subscriber.public_methods(false).reject{ |method| method.to_s == 'call' }
    events.each do |event|
      ActiveSupport::Notifications.notifier.listeners_for("#{event}.#{component}").each do |listener|
        if listener.instance_variable_get('@delegate') == subscriber
          ActiveSupport::Notifications.unsubscribe listener
        end
      end
    end
  end

  def self.setup(app)
    app.config.action_dispatch.rack_cache[:verbose] = false if app.config.action_dispatch.rack_cache
    require 'lograge/rails_ext/rack/logger'
    Lograge.remove_existing_log_subscriptions
    Lograge::RequestLogSubscriber.attach_to :action_controller
    Lograge.custom_options = app.config.lograge.custom_options
    Lograge.custom_prefixes = app.config.lograge.custom_prefixes
  end
end

require 'lograge/railtie' if defined?(Rails)
