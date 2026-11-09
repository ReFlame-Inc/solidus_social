# frozen_string_literal: true

class Spree::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include Spree::Core::ControllerHelpers::Common
  include Spree::Core::ControllerHelpers::Order
  include Spree::Core::ControllerHelpers::Auth
  include Spree::Core::ControllerHelpers::Store
  include SolidusSocial::StorefrontNavigation

  class << self
    def provides_callback_for(*providers)
      providers.each do |provider|
        define_method(provider) { omniauth_callback }
      end
    end
  end

  Spree::SocialConfig.providers.keys.each do |provider|
    provides_callback_for provider
  end

  def omniauth_callback
    session.delete(:omniauth)
    if request.env['omniauth.error'].present?
      flash[:error] = I18n.t('devise.omniauth_callbacks.failure', kind: auth_hash['provider'], reason: I18n.t('spree.user_was_not_valid'))
      redirect_to social_storefront.login_path
      return
    end

    authentication = Spree::UserAuthentication.find_by(provider: auth_hash['provider'], uid: auth_hash['uid'])

    if spree_current_user && authentication && authentication.user != spree_current_user
      return redirect_to social_storefront.account_path, alert: I18n.t('spree.social_identity_conflict')
    end

    if authentication.present? && authentication.try(:user).present?
      flash[:notice] = I18n.t('devise.omniauth_callbacks.success', kind: auth_hash['provider'])
      sign_in_and_redirect :spree_user, authentication.user
    elsif spree_current_user
      spree_current_user.apply_omniauth(auth_hash)
      spree_current_user.save!
      flash[:notice] = I18n.t('devise.sessions.signed_in')
      redirect_to social_storefront.account_path
    else
      email = auth_hash.dig('info', 'email')
      if email.present? && Spree.user_class.find_for_authentication(email: email)
        return redirect_to social_storefront.login_path, alert: I18n.t('spree.social_sign_in_to_link')
      end
      user = Spree.user_class.new
      user.apply_omniauth(auth_hash)
      if user.save
        flash[:notice] = I18n.t('devise.omniauth_callbacks.success', kind: auth_hash['provider'])
        sign_in_and_redirect :spree_user, user
      else
        session[:omniauth] = { 'provider' => auth_hash['provider'], 'uid' => auth_hash['uid'], 'info' => { 'email' => email } }
        flash[:notice] = I18n.t('spree.one_more_step', kind: auth_hash['provider'].capitalize)
        redirect_to social_storefront.signup_path
        return
      end
    end

    if current_order
      user = spree_current_user || authentication&.user || user
      current_order.associate_user!(user)
      session[:guest_token] = nil
    end
  rescue ActiveRecord::RecordNotUnique
    raise unless Spree::UserAuthentication.exists?(provider: auth_hash['provider'], uid: auth_hash['uid'])

    redirect_to(spree_current_user ? social_storefront.account_path : social_storefront.login_path,
      alert: I18n.t('spree.social_identity_conflict'))
  end

  def failure
    set_flash_message :alert, :failure, kind: failed_strategy.name.to_s.humanize, reason: failure_message
    session.delete(:omniauth)
    redirect_to social_storefront.login_path
  end

  def passthru
    render file: "#{Rails.root}/public/404.html", formats: [:html], status: :not_found, layout: false
  end

  def auth_hash
    request.env['omniauth.auth']
  end
end
