# frozen_string_literal: true

class AddUniqueSocialIdentityIndex < ActiveRecord::Migration[5.2]
  def up
    return if connection.indexes(:spree_user_authentications).any? { |index| index.unique && !index.where && index.columns == %w[provider uid] }

    add_index :spree_user_authentications, [:provider, :uid], unique: true, name: 'solidus_social_unique_identity'
  end

  def down
    return unless connection.indexes(:spree_user_authentications).any? { |index| index.name == 'solidus_social_unique_identity' }

    remove_index :spree_user_authentications, name: 'solidus_social_unique_identity'
  end
end
