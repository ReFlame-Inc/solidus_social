# frozen_string_literal: true

unless Rails.application.routes.url_helpers.method_defined?(:login_path)
  module StorefrontTest
    LAYOUT = <<~ERB
      <!DOCTYPE html>
      <html>
        <head><link rel="icon" href="data:,"></head>
        <body>
          <nav>
            <% if spree_current_user %>
              <%= link_to "My Account", main_app.account_path %>
              <%= link_to "Logout", main_app.logout_path %>
            <% else %>
              <%= link_to "Login", main_app.login_path %>
            <% end %>
          </nav>
          <% flash.each do |_key, message| %>
            <div class="flash"><%= message %></div>
          <% end %>
          <%= content %>
        </body>
      </html>
    ERB

    module ControllerHelpers
      extend ActiveSupport::Concern

      included do
        include Spree::Core::ControllerHelpers::Common
        include Spree::Core::ControllerHelpers::Order
        include Spree::Core::ControllerHelpers::Auth
        include Spree::Core::ControllerHelpers::Store
        include SolidusSocial::StorefrontRoutes
      end

      private

      def render_storefront(body)
        render inline: StorefrontTest::LAYOUT, locals: {content: body.html_safe}
      end
    end

    class HomeController < ActionController::Base
      include ControllerHelpers

      def index
        render_storefront("<p>Home</p>")
      end
    end
  end

  class UserSessionsController < Devise::SessionsController
    include StorefrontTest::ControllerHelpers

    def new
      self.resource = resource_class.new(sign_in_params)
      body = render_to_string(inline: '<%= render "spree/shared/social" %>')
      render_storefront(body)
    end

    def destroy
      sign_out(:spree_user)
      redirect_to main_app.root_path
    end
  end

  class UserRegistrationsController < Devise::RegistrationsController
    include StorefrontTest::ControllerHelpers

    prepend SolidusSocial::Spree::UserRegistrationsControllerDecorator

    def new
      build_resource
      body = render_to_string(inline: <<~ERB)
        <div id="new-customer">
          <%= render "spree/users/new-customer" %>
          <%= form_for(resource, as: :spree_user, url: main_app.registration_path) do |f| %>
            <%= f.label :email, "Email" %>
            <%= f.email_field :email %>
            <%= f.submit "Create" %>
          <% end %>
          <%= render "spree/shared/social" unless session[:omniauth] %>
        </div>
      ERB
      render_storefront(body)
    end

    protected

    def after_sign_up_path_for(_resource)
      main_app.root_path
    end
  end

  class UsersController < ActionController::Base
    include StorefrontTest::ControllerHelpers

    def show
      body = render_to_string(inline: <<~ERB)
        <h1>My Account</h1>
        <%= render "spree/users/social" %>
      ERB
      render_storefront(body)
    end
  end

  Rails.application.routes.append do
    get "/favicon.ico", to: proc { [204, {}, []] }
    root to: "storefront_test/home#index"

    devise_scope :spree_user do
      get "/login", to: "user_sessions#new", as: :login
      get "/logout", to: "user_sessions#destroy", as: :logout
      get "/signup", to: "user_registrations#new", as: :signup
      post "/signup", to: "user_registrations#create", as: :registration
    end

    get "/account", to: "users#show", as: :account
  end
  Rails.application.reload_routes!
end
