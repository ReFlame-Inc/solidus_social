# frozen_string_literal: true

require 'uri'
abort 'An isolated test database is required' unless ENV['RAILS_ENV'] == 'test' && URI.parse(ENV.fetch('DATABASE_URL')).path.end_with?('_test')
require 'rails_helper'

RSpec.describe 'Google identity binding', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:owner) { Spree.user_class.create!(email: 'owner@example.com', password: 'owner-password') }
  let(:shopper) { Spree.user_class.create!(email: 'shopper@example.com', password: 'shopper-password') }
  let(:identity) { { provider: 'google_oauth2', uid: 'google-id' } }

  around do |example|
    mode = OmniAuth.config.test_mode
    previous = OmniAuth.config.mock_auth.dup
    OmniAuth.config.test_mode = true
    example.run
  ensure
    OmniAuth.config.test_mode = mode
    OmniAuth.config.mock_auth = previous
  end

  def callback(email)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(identity.merge(info: { email: email }, credentials: { token: 'fixture' }))
    get '/users/auth/google_oauth2/callback'
  end

  it 'retains the shopper session when a Google identity belongs to another account' do
    owner.user_authentications.create!(identity)
    sign_in shopper
    callback(owner.email)
    expect(response).to redirect_to('/account')
    expect(request.env['warden'].user(:spree_user)).to eq(shopper)
    expect(shopper.user_authentications.reload).to be_empty
  end

  it 'requires the existing account holder to sign in before linking' do
    callback(owner.email)
    expect(response).to redirect_to('/login')
    expect(request.env['warden'].user(:spree_user)).to be_nil
    expect(owner.user_authentications.reload).to be_empty
  end

  it 'retains only the registration fields when email is missing' do
    callback(nil)
    expect(response).to redirect_to('/signup')
    expect(session[:omniauth]).to eq(identity.stringify_keys.merge('info' => { 'email' => nil }))
  end

  it 'enforces identity ownership at the database boundary' do
    owner.user_authentications.create!(identity)
    expect { shopper.user_authentications.create!(identity) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'clears pending signup when the identity has since been claimed' do
    callback(nil)
    owner.user_authentications.create!(identity)
    expect {
      post '/signup', params: { spree_user: { email: 'new-shopper@example.com' } }
    }.not_to change(Spree.user_class, :count)
    expect(response).to be_redirect
    expect(session[:omniauth]).to be_nil
    expect(request.env['warden'].user(:spree_user)).to be_nil
  end

  it 'excludes disabled providers from the available services' do
    Spree::AuthenticationMethod.create!(provider: 'google_oauth2', active: false, environment: Rails.env)
    expect(Spree::AuthenticationMethod.available_for(nil)).to be_empty
  end
end
