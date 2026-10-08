# frozen_string_literal: true

# Defines plugin-wide constants. Zeitwerk loads the remaining files, so each
# must define the constant implied by its path; do not add manual requires here.
module RedmineMcpPlugin
  VERSION = '0.1.0'

  # Supported MCP revisions, newest first. Older handshake revisions remain for
  # compatibility with shipped clients; see Protocol.
  SUPPORTED_PROTOCOL_VERSIONS = %w[2026-07-28 2025-11-25 2025-06-18].freeze

  PREFERRED_PROTOCOL_VERSION = '2026-07-28'

  # Per the transport spec: absent MCP-Protocol-Version header means 2025-03-26.
  # We treat it as the oldest revision we serve instead, which is wire
  # compatible for the handful of methods we implement.
  FALLBACK_PROTOCOL_VERSION = '2025-06-18'
end
