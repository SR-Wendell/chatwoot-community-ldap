# frozen_string_literal: true

module SuperAdminLdapAuthenticationPatch
  private

  def valid_credentials?
    email =
      params.dig(:super_admin, :email)
            .to_s
            .strip
            .downcase

    password =
      params.dig(:super_admin, :password)
            .to_s

    return invalid_super_admin_login(email) if email.blank? || password.blank?

    #
    # O usuário obrigatoriamente precisa existir LOCALMENTE
    # como SuperAdmin.
    #
    @super_admin = SuperAdmin.find_by(email: email)

    return invalid_super_admin_login(email) unless @super_admin

    #
    # 1. Tenta a senha LOCAL do Chatwoot.
    #
    if @super_admin.valid_password?(password)
      Rails.logger.info(
        "[SUPERADMIN] Login LOCAL realizado: #{email}"
      )

      return true
    end

    #
    # 2. Senha local não funcionou.
    # Tenta autenticação no Active Directory.
    #
    identity =
      LdapAuthenticationService.authenticate_and_fetch(
        login: email,
        password: password
      )

    unless identity
      Rails.logger.warn(
        "[SUPERADMIN][LDAP] Credenciais AD recusadas: #{email}"
      )

      return invalid_super_admin_login(email)
    end

    #
    # 3. Confirma que o usuário também pertence ao grupo
    # autorizado de SuperAdmins no AD.
    #
    required_group =
      ENV.fetch('LDAP_SUPER_ADMINS_GROUP').downcase

    groups =
      Array(identity[:groups])
        .map(&:to_s)
        .map(&:downcase)

    unless groups.include?(required_group)
      Rails.logger.warn(
        "[SUPERADMIN][LDAP] #{email} autenticou no AD, " \
        "mas não pertence ao grupo de SuperAdmins"
      )

      return invalid_super_admin_login(email)
    end

    Rails.logger.info(
      "[SUPERADMIN][LDAP] Login AD realizado: #{email}"
    )

    true
  rescue StandardError => e
    Rails.logger.error(
      "[SUPERADMIN] Erro de autenticação para #{email}: " \
      "#{e.class}: #{e.message}"
    )

    invalid_super_admin_login(email)
  end

  def invalid_super_admin_login(email)
    @error_message = 'Invalid credentials. Please try again.'

    Rails.logger.warn(
      "[SUPERADMIN] Login recusado: #{email}"
    )

    false
  end
end
