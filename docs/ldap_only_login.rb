# frozen_string_literal: true

Rails.application.config.to_prepare do
  unless DeviseOverrides::SessionsController < LdapOnlyLoginPatch
    DeviseOverrides::SessionsController.prepend(
      LdapOnlyLoginPatch
    )
  end
end
