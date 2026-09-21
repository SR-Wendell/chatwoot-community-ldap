# frozen_string_literal: true

require 'net/ldap'
require 'openssl'

class LdapAuthenticationService
  CA_FILE = '/etc/ssl/certs/ca-certificates.crt'

  def self.authenticate_and_fetch(login:, password:)
    return nil if login.blank? || password.blank?

    login = login.strip.downcase

    # 1. Valida a senha DIRETAMENTE no Active Directory
    user_ldap = build_connection(
      username: login,
      password: password
    )

    return nil unless user_ldap.bind

    # 2. Depois do login válido, usa a conta de serviço
    # para buscar os atributos do usuário.
    service_ldap = build_connection(
      username: ENV.fetch('LDAP_BIND_DN'),
      password: ENV.fetch('LDAP_BIND_PASSWORD')
    )

    return nil unless service_ldap.bind

    username = login.split('@').first

    filter =
      Net::LDAP::Filter.eq('userPrincipalName', login) |
      Net::LDAP::Filter.eq('mail', login) |
      Net::LDAP::Filter.eq('sAMAccountName', username)

    entry = service_ldap.search(
      base: ENV.fetch('LDAP_BASE_DN'),
      filter: filter,
      attributes: %w[
        mail
        userPrincipalName
        sAMAccountName
        displayName
        cn
        memberOf
      ]
    )&.first

    return nil unless entry

    email =
      entry[:mail].first.presence ||
      entry[:userprincipalname].first.presence ||
      login

    name =
      entry[:displayname].first.presence ||
      entry[:cn].first.presence ||
      email.split('@').first

    {
      email: email.to_s.downcase,
      name: name.to_s,
      dn: entry.dn,
      groups: entry[:memberof].map(&:to_s)
    }
  rescue StandardError => e
    Rails.logger.error(
      "[LDAP] #{e.class}: #{e.message}"
    )

    nil
  end

  def self.build_connection(username:, password:)
    Net::LDAP.new(
      host: ENV.fetch('LDAP_HOST'),
      port: ENV.fetch('LDAP_PORT', '636').to_i,

      encryption: {
        method: :simple_tls,
        tls_options: {
          verify_mode: OpenSSL::SSL::VERIFY_PEER,
          ca_file: CA_FILE
        }
      },

      auth: {
        method: :simple,
        username: username,
        password: password
      }
    )
  end
end
