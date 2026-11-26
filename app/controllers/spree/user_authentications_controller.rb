# frozen_string_literal: true

# Spree::StoreController comes from the legacy solidus_frontend; generated
# storefronts define ::StoreController in the host application instead.
class Spree::UserAuthenticationsController < "Spree::StoreController".safe_constantize || "::StoreController".safe_constantize || Spree::BaseController
  include SolidusSocial::StorefrontRoutes

  def index
    @authentications = spree_current_user.user_authentications if spree_current_user
  end

  def destroy
    @authentication = spree_current_user.user_authentications.find(params[:id])
    @authentication.destroy
    flash[:notice] = I18n.t("spree.destroy", scope: :authentications)
    redirect_to storefront_path(:account_path)
  end
end
