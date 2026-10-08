# MCP core change guide

Use this guide for changes to MCP routing, transport behavior, authentication,
protocol handling, dispatch, tool registration, validation, authorization, or
tool execution. Read the [current architecture](../ARCHITECTURE.md) first; its
request flow and security invariants are the acceptance boundary for this area.
Repository-wide conventions and host-backed commands remain in
[`AGENTS.md`](../../AGENTS.md).

## Put behavior at its owning seam

| Concern | Authoritative seam | Boundary test |
|---|---|---|
| Mounted HTTP verbs and endpoint paths | [`config/routes.rb`](../../config/routes.rb) | Functional or integration route request |
| HTTP status, controller gates, Origin, body parsing | [`McpController`](../../app/controllers/mcp_controller.rb) | `test/functional/mcp_controller_test.rb` |
| Credential selection and Redmine user resolution | [`Authenticator`](../../lib/redmine_mcp_plugin/authenticator.rb) | Controller test at the authentication boundary |
| Supported revisions and response metadata | [`lib/redmine_mcp_plugin.rb`](../../lib/redmine_mcp_plugin.rb) and [`Protocol`](../../lib/redmine_mcp_plugin/protocol.rb) | `test/unit/protocol_test.rb` plus controller coverage when HTTP behavior changes |
| MCP methods and JSON-RPC error mapping | [`Dispatcher`](../../lib/redmine_mcp_plugin/dispatcher.rb) and [`JsonRpc`](../../lib/redmine_mcp_plugin/json_rpc.rb) | Controller request exercising the public response |
| Exposed tool set | [`Registry.all`](../../lib/redmine_mcp_plugin/registry.rb) | `tools/list` and `tools/call` controller tests |
| Shared permission, read-only, pagination, and lookup behavior | [`Tool`](../../lib/redmine_mcp_plugin/tool.rb) | Focused unit test and affected public tool call |
| Accepted argument shapes and coercion | Tool schema plus [`SchemaValidator`](../../lib/redmine_mcp_plugin/schema_validator.rb) | `test/unit/schema_validator_test.rb` and the affected tool call |
| Redmine queries and result serialization | The class under [`lib/redmine_mcp_plugin/tools/`](../../lib/redmine_mcp_plugin/tools/) | Functional test using Redmine fixtures and visibility rules |
| OAuth discovery and client registration | [`McpMetadataController`](../../app/controllers/mcp_metadata_controller.rb) and [`DynamicClientRegistration`](../../lib/redmine_mcp_plugin/dynamic_client_registration.rb) | Metadata functional tests and OAuth integration tests |

Keep the controller limited to HTTP and security gates and keep `Dispatcher`
independent of HTTP. Add a tool by defining its metadata and implementation in a
Zeitwerk-matching class, then adding that class explicitly to `Registry.all`; a
file under `tools/` alone is not exposed.

## Integrate through Redmine

- Read plugin configuration through `RedmineMcpPlugin::Settings`, which normalizes
  Redmine's `Setting.plugin_redmine_mcp_plugin` values. Declare administrator
  defaults in `Settings::DEFAULTS` and keep the settings partial consistent with
  them.
- Resolve identities and permissions with Redmine APIs. OAuth tokens come from
  Doorkeeper; API keys, Basic credentials, sessions, active-user state, and
  `User.current` come from Redmine. Preserve OAuth scopes when passing request
  context to tools.
- Begin record access with Redmine's visibility scope or record-level visibility
  predicate. Pair it with the relevant `User#allowed_to?` check; one does not
  replace the other.
- Keep the documented lazy-load exception confined to the external
  `doorkeeper-openid_connect` integration, whose timing avoids early controller
  binding.
- Apply schema changes to Redmine's database through a reversible plugin migration.
  Guard shared or gem-owned structures where compatibility requires idempotence.
- Match coverage to the seam table: use unit tests for pure policy and functional
  or integration coverage for a changed public boundary or host integration.

Direct overrides or monkey patches of Redmine controllers and models are
exceptional architecture changes. Require explicit architectural justification
next to the integration point and focused tests proving loading, authorization,
and behavior in the supported Redmine host. Prefer Redmine's public extension
points and model scopes whenever they can express the change.

## Preserve the security chain

For every core change, walk the request flow and enumerate every applicable
[security invariant](../ARCHITECTURE.md#security-invariants). Add focused coverage
at the first public boundary where each regression would be observable. A
security-sensitive change needs both a refusal case and the permitted case,
including a scope- or visibility-limited caller when relevant. This check is
complete only when every applicable invariant is accounted for or explicitly
identified as unaffected.

## Completion check

A core change is complete when its implementation lives at the owning seam, every
affected architecture invariant has focused boundary coverage, relevant focused
tests pass, and the repository-wide validation required by
[`AGENTS.md`](../../AGENTS.md) is complete. Update the architecture document only
when the implemented boundary or flow changed; update the operator README only
when public setup or capabilities changed.
