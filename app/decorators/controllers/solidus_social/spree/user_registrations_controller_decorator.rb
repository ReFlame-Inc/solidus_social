# frozen_string_literal: true

module SolidusSocial
  module Spree
    module UserRegistrationsControllerDecorator
      def self.prepended(base)
        base.class_eval do
          after_action :clear_omniauth, only: :create
        end
      end

      def create
        super
      rescue ActiveRecord::RecordNotUnique
        pending = session[:omniauth]
        raise unless pending && ::Spree::UserAuthentication.exists?(pending.slice('provider', 'uid'))

        session.delete(:omniauth)
        routes = 'UserRegistrationsController'.safe_constantize ? main_app : spree
        redirect_to routes.login_path, alert: I18n.t('spree.social_identity_conflict')
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

      controller = 'UserRegistrationsController'.safe_constantize ||
        'Spree::UserRegistrationsController'.safe_constantize
      controller.prepend(self) if controller && !controller.ancestors.include?(self)
    end
  end
end
