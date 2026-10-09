# frozen_string_literal: true

module RedmineMcpPlugin
  # Composes OAuth insufficient-scope challenges and owns the permission
  # correlation policy used for step-up. Correlations may bundle only scopes in
  # the challenged operation's tier: a read challenge must never introduce a
  # write scope. When adding a correlation, declare every member's tier in
  # SCOPE_TIERS; header composition enforces that all members stay in the
  # operation's tier.
  module ScopeChallenge
    ERROR_DESCRIPTION = 'The access token lacks the scope required for this operation'
    SCOPE_TIERS = {
      admin: :write,
      add_issues: :write,
      add_issue_notes: :write,
      set_notes_private: :write
    }.freeze
    CORRELATED_SCOPES = {
      add_issues: %i[add_issue_notes].freeze
    }.freeze

    module_function

    def header(permissions:, write:, resource_metadata:)
      scopes = permissions.flat_map { |permission| challenge_scopes(permission, write: write) }.uniq
      'Bearer error="insufficient_scope", ' \
        "scope=\"#{scopes.join(' ')}\", " \
        "resource_metadata=\"#{resource_metadata}\", " \
        "error_description=\"#{ERROR_DESCRIPTION}\""
    end

    def challenge_scopes(permission, write:)
      permission = permission.to_sym
      correlated = CORRELATED_SCOPES.fetch(permission, [])
      expected_tier = write ? :write : :read
      if SCOPE_TIERS.key?(permission) && SCOPE_TIERS.fetch(permission) != expected_tier
        raise ArgumentError, "scope set crosses the #{expected_tier} boundary"
      end
      correlated.each do |scope|
        next if SCOPE_TIERS.fetch(scope) == expected_tier

        raise ArgumentError, "scope set crosses the #{expected_tier} boundary"
      end
      [permission, *correlated]
    end
    private_class_method :challenge_scopes
  end
end
