# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class McpMetadataControllerTest < Redmine::ControllerTest
  tests McpMetadataController

  def setup
    Setting.plugin_redmine_mcp_plugin =
      RedmineMcpPlugin::Settings::DEFAULTS.merge(
        'enabled' => '1',
        'auth_oauth2' => '1',
        'dcr_enabled' => '1'
      )
    Setting.clear_cache
  end

  def teardown
    Setting.clear_cache
  end

  def test_authorization_server_advertises_registration_when_dcr_is_enabled
    get :authorization_server

    assert_response :success
    assert_equal 'http://test.host/oauth/registration', JSON.parse(response.body)['registration_endpoint']
  end

  def test_authorization_server_omits_registration_when_dcr_is_disabled
    Setting.plugin_redmine_mcp_plugin =
      RedmineMcpPlugin::Settings::DEFAULTS.merge('enabled' => '1', 'auth_oauth2' => '1', 'dcr_enabled' => '0')
    Setting.clear_cache

    get :authorization_server

    assert_response :success
    assert_not JSON.parse(response.body).key?('registration_endpoint')
  end
end
