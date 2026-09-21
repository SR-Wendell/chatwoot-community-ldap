# frozen_string_literal: true

module LdapOnlyLoginPatch
  def create
    # Mantém a segunda etapa do MFA funcionando.
    return super if mfa_verification_request?

    email = params[:email].to_s.strip.downcase
    password = params[:password].to_s

    if email.blank? || password.blank?
      return render_create_error_bad_credentials
    end

    #
    # SEM fallback local.
    #
    # Se o AD não autenticar, acabou.
    #
    identity =
      LdapAuthenticationService.authenticate_and_fetch(
        login: email,
        password: password
      )

    unless identity
      Rails.logger.warn(
        "[LDAP] Login recusado pelo AD: #{email}"
      )

      return render_create_error_bad_credentials
    end

    #
    # AD autenticou.
    #
    # Usuário existente → preserva.
    # Usuário inexistente → cria.
    #
    @resource =
      LdapUserProvisioningService.find_or_create!(
        identity
      )

    unless @resource&.active_for_authentication?
      return render_create_error_not_confirmed
    end

    # Mantém MFA do próprio Chatwoot.
    if @resource.mfa_enabled?
      return handle_mfa_required(@resource)
    end

    # Mantém controle de sessões existente.
    return if enforce_session_limit_for_password_login(@resource)

    #
    # Cria a sessão/token normal do Chatwoot.
    #
    @token = @resource.create_token
    @resource.save!

    sign_in(
      :user,
      @resource,
      store: false,
      bypass: false
    )

    Rails.logger.info(
      "[LDAP] Login AD realizado: #{@resource.email}"
    )

    render_create_success

  rescue StandardError => e
    Rails.logger.error(
      "[LDAP] Erro no login: #{e.class}: #{e.message}"
    )

    render json: {
      errors: ['Erro ao autenticar no diretório corporativo']
    }, status: :internal_server_error
  end
end
