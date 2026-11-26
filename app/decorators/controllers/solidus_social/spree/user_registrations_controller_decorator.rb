# frozen_string_literal: true

module SolidusSocial
  module Spree
    module UserRegistrationsControllerDecorator
      def self.prepended(base)
        base.class_eval do
          after_action :clear_omniauth, only: :create
        end
      end

      private

      def build_resource(*args)
        super
        resource.apply_omniauth(session[:omniauth]) if session[:omniauth]
        resource
      end

      def clear_omniauth
        session.delete(:omniauth) if resource&.persisted?
      end

      # The legacy solidus_frontend ships Spree::UserRegistrationsController,
      # while generated storefronts (solidus_starter_frontend) define a
      # top-level UserRegistrationsController in the host application.
      %w[UserRegistrationsController Spree::UserRegistrationsController].each do |name|
        controller = name.safe_constantize
        next unless controller
        next if controller.ancestors.include?(self)

        controller.prepend(self)
      end
    end
  end
end
