# frozen_string_literal: true

# Serves the MCP Streamable HTTP endpoint. This controller and Authenticator own
# the security boundary; Dispatcher handles only protocol messages.
class McpController < ApplicationController
  # Token clients cannot provide Rails CSRF tokens. Cookie authentication
  # remains protected by the mandatory Origin check in #verify_origin.
  skip_before_action :verify_authenticity_token

  # Core's check_if_login_required runs before our authentication and would
  # answer 302/403 for every request when login_required is on, so the
  # X-Redmine-API-Key or Bearer header would never be looked at.
  skip_before_action :check_if_login_required, raise: false

  before_action :require_endpoint_enabled
  before_action :verify_origin
  before_action :authenticate_mcp_request
  before_action :verify_protocol_version

  def handle
    body = request.body.read.to_s

    begin
      message = JSON.parse(body)
    rescue JSON::ParserError
      return render_rpc(RedmineMcpPlugin::JsonRpc.error(nil, RedmineMcpPlugin::JsonRpc::PARSE_ERROR, 'Parse error'), :bad_request)
    end

    # Supported MCP revisions forbid batches; never process only part of one.
    if message.is_a?(Array)
      return render_rpc(
        RedmineMcpPlugin::JsonRpc.error(nil, RedmineMcpPlugin::JsonRpc::INVALID_REQUEST,
                                        'JSON-RPC batching is not supported by this protocol version'),
        :bad_request
      )
    end

    unless message.is_a?(Hash) && message['method'].present?
      return render_rpc(
        RedmineMcpPlugin::JsonRpc.error(nil, RedmineMcpPlugin::JsonRpc::INVALID_REQUEST, 'Invalid Request'),
        :bad_request
      )
    end

    unless message['jsonrpc'] == '2.0'
      return render_rpc(
        RedmineMcpPlugin::JsonRpc.error(message['id'], RedmineMcpPlugin::JsonRpc::INVALID_REQUEST,
                                        'Invalid Request: jsonrpc must be "2.0"'),
        :bad_request
      )
    end

    # A notification gets 202 Accepted with no body, per the transport spec.
    # notifications/initialized from an older client lands here.
    if RedmineMcpPlugin::JsonRpc.notification?(message)
      return head :accepted
    end

    dispatcher = RedmineMcpPlugin::Dispatcher.new(
      user: User.current, auth: @mcp_auth, protocol_version: @mcp_protocol_version
    )
    render_rpc(dispatcher.call(message), :ok)
  end

  # Returns 405 because this server provides no server-to-client stream.
  def stream
    render json: { error: 'This server does not offer a server-to-client stream' },
           status: :method_not_allowed
  end

  # Returns 405 because this server never issues transport sessions.
  def terminate
    head :method_not_allowed
  end

  private

  def require_endpoint_enabled
    return if RedmineMcpPlugin::Settings.enabled?

    render json: { error: 'The MCP endpoint is disabled. An administrator can enable it under ' \
                          'Administration > Plugins > Redmine MCP Server.' },
           status: :forbidden
  end

  # DNS-rebinding protection, which the transport spec makes a MUST.
  #
  # MCP clients outside a browser normally send no Origin header, so they are
  # unaffected. A browser sends one, which makes this an effective guard for
  # the cookie-authenticated mode.
  def verify_origin
    origin = request.headers['Origin'].presence
    return if origin.nil?
    return if origin == request.base_url
    return if RedmineMcpPlugin::Settings.allowed_origins.include?(origin)

    render json: { error: 'Origin not allowed' }, status: :forbidden
  end

  def authenticate_mcp_request
    result = RedmineMcpPlugin::Authenticator.new(request, self).authenticate

    unless result.ok?
      if RedmineMcpPlugin::Settings.oauth2_auth? && result.status == :unauthorized
        # RFC 9728 resource metadata tells the client which authorization server
        # can issue the required bearer token.
        response.set_header(
          'WWW-Authenticate',
          %(Bearer realm="Redmine", resource_metadata="#{oauth_protected_resource_url}")
        )
      end
      return render json: { error: result.error }, status: result.status
    end

    User.current = result.user
    @mcp_auth = { mode: result.mode, scopes: result.scopes }
  end

  def verify_protocol_version
    header = request.headers['MCP-Protocol-Version'].presence
    @mcp_protocol_version = header || RedmineMcpPlugin::FALLBACK_PROTOCOL_VERSION
    return if header.nil? || RedmineMcpPlugin::Protocol.supported?(header)

    render json: RedmineMcpPlugin::JsonRpc.error(
      nil, RedmineMcpPlugin::JsonRpc::UNSUPPORTED_PROTOCOL_VERSION,
      "Unsupported MCP protocol version: #{header}",
      { supported: RedmineMcpPlugin::SUPPORTED_PROTOCOL_VERSIONS }
    ), status: :bad_request
  end

  def oauth_protected_resource_url
    base = request.base_url + (Redmine::Utils.relative_url_root.presence || '')
    "#{base}/.well-known/oauth-protected-resource/mcp"
  end

  def render_rpc(payload, status)
    render json: payload, status: status, content_type: 'application/json'
  end
end
