# frozen_string_literal: true

require 'securerandom'

class LdapUserProvisioningService
  def self.find_or_create!(identity)
    email = identity.fetch(:email).downcase

    #
    # Se já existe: NÃO altera absolutamente nada.
    #
    existing_user = User.from_email(email)
    return existing_user if existing_user

    account = Account.find(
      ENV.fetch('LDAP_ACCOUNT_ID', '1')
    )

    groups = identity.fetch(:groups, [])

    admins_group = ENV.fetch('LDAP_ADMINS_GROUP')
    users_group  = ENV.fetch('LDAP_USERS_GROUP')

    #
    # Usuário precisa pertencer a um dos grupos permitidos.
    #
    unless groups.include?(admins_group) ||
           groups.include?(users_group)

      raise "Usuário LDAP sem permissão para acessar o Chatwoot"
    end

    #
    # Admin tem prioridade.
    #
    role =
      if groups.include?(admins_group)
        'administrator'
      else
        'agent'
      end

    User.transaction do
      random_password =
        "#{SecureRandom.base64(48)}Aa1!"

      user = User.new(
        email: email,
        name: identity.fetch(:name),
        password: random_password,
        password_confirmation: random_password
      )

      user.skip_confirmation!
      user.save!

      AccountUser.create!(
        account: account,
        user: user,
        role: role
      )

      Rails.logger.info(
        "[LDAP] Novo usuário #{email} provisionado como #{role}"
      )

      user
    end

  rescue ActiveRecord::RecordNotUnique
    User.from_email(email)
  end
end
