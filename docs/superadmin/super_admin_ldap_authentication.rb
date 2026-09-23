# frozen_string_literal: true

Rails.application.config.to_prepare do
  controller =
    SuperAdmin::Devise::SessionsController

  unless controller < SuperAdminLdapAuthenticationPatch
    controller.prepend(
      SuperAdminLdapAuthenticationPatch
    )
  end
end
