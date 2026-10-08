# frozen_string_literal: true

module RedmineMcpPlugin
  # Configures the MCP Ruby SDK and builds a server carrying this plugin's
  # identity and instructions. It owns how an unexpected exception is reported
  # and how the server introduces itself. The controller builds one server for
  # each authenticated request with only that caller's visible tools.
  module McpServer
    INSTRUCTIONS =
      'Redmine over MCP. Every tool runs as the authenticated Redmine user and is ' \
      'limited by that user\'s project permissions, and by the OAuth2 scopes of the ' \
      'presented token where one is used. Results are already filtered; an empty ' \
      'result means nothing visible matched, not that nothing exists.'

    # Reports an unexpected exception to the Redmine log in the SDK's two-argument
    # reporter shape. The SDK already strips the exception message from the
    # client's response -- a tool fault surfaces only as a generic "Internal
    # error" so internals (SQL, paths, record contents) cannot leak (CWE-209) --
    # which leaves the log as the only place the cause survives. Kept in the same
    # established `[redmine_mcp_plugin] Class: message` shape. The second
    # argument is the SDK's per-call reporter context, unused here.
    EXCEPTION_REPORTER = lambda do |exception, _server_context|
      Rails.logger.error(
        "[redmine_mcp_plugin] #{exception.class}: #{exception.message}\n" \
        "#{exception.backtrace&.first(15)&.join("\n")}"
      )
    end

    module_function

    # Installs the exception reporter on the SDK's global configuration,
    # replacing its no-op default. Idempotent: a server captures this
    # configuration when it is constructed, so build calls this first.
    def configure!
      MCP.configuration.exception_reporter = EXCEPTION_REPORTER
    end

    # Builds a stateless MCP server. `tools` and `server_context` default empty
    # so an initialize/ping handshake answers before any tool is wired in.
    def build(tools: [], server_context: nil)
      configure!

      MCP::Server.new(
        name: 'redmine-mcp-plugin',
        title: 'Redmine',
        version: RedmineMcpPlugin::VERSION,
        instructions: INSTRUCTIONS,
        tools: tools,
        server_context: server_context
      )
    end
  end
end
