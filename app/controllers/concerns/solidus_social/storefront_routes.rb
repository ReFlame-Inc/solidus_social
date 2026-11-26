# frozen_string_literal: true

module SolidusSocial
  # Storefront pages (login, signup, account) are drawn inside the Spree
  # engine by the legacy solidus_frontend, but in the host application by a
  # generated storefront such as solidus_starter_frontend. Resolve them from
  # whichever route set defines them, preferring the host application.
  module StorefrontRoutes
    private

    def storefront_path(*route_names)
      [main_app, spree].each do |routes|
        route_names.each do |name|
          return routes.public_send(name) if routes.respond_to?(name)
        end
      end

      raise NoMethodError, "No storefront route found for #{route_names.join(", ")}"
    end
  end
end
