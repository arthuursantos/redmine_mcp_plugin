# frozen_string_literal: true

# Defines plugin-wide constants. Zeitwerk loads the remaining files, so each
# must define the constant implied by its path; do not add manual requires here.
module RedmineMcpPlugin
  VERSION = '0.1.0'

  # Transport revisions accepted by the controller, newest first. Older
  # revisions remain for compatibility with shipped clients.
  SUPPORTED_PROTOCOL_VERSIONS = %w[2026-07-28 2025-11-25 2025-06-18].freeze
end
