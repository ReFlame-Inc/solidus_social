# frozen_string_literal: true

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

# Run Coverage report
require "solidus_dev_support/rspec/coverage"

require File.expand_path("dummy/config/environment.rb", __dir__)

# Requires factories and other useful helpers defined in spree_core.
require "solidus_dev_support/rspec/feature_helper"
require "capybara/selenium/driver_specializations/chrome_driver"
require "uri"

module Chrome158CdpStorageClearCompat
  def execute_cdp(cmd, params = {})
    super
  rescue Selenium::WebDriver::Error::InvalidArgumentError
    raise unless cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"

    execute_cdp("Network.clearBrowserCookies")
    if params[:storageTypes].to_s.include?("local_storage")
      entries = execute_cdp("Page.getNavigationHistory").fetch("entries", [])
      entries.filter_map { |entry| http_origin_for(entry["url"]) }.uniq.each do |origin|
        execute_cdp("Storage.clearDataForOrigin", origin: origin, storageTypes: "local_storage")
      end
    end
  end

  private

  def http_origin_for(url)
    uri = URI.parse(url.to_s)
    return unless %w[http https].include?(uri.scheme) && uri.host

    port_part = (uri.port == uri.default_port) ? "" : ":#{uri.port}"
    "#{uri.scheme}://#{uri.host}#{port_part}"
  rescue URI::InvalidURIError
    nil
  end
end

Capybara::Selenium::Driver::ChromeDriver.prepend(Chrome158CdpStorageClearCompat)

SolidusDevSupport::TestingSupport::Factories.load_for(SolidusSocial::Engine, Spree::Auth::Engine)

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.use_transactional_fixtures = false
end
