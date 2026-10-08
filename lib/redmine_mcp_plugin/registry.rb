# frozen_string_literal: true

module RedmineMcpPlugin
  # Explicitly registers exposed tools so a stray file cannot become an
  # authenticated endpoint without a visible registry change.
  module Registry
    class << self
      def all
        [
          Tools::WhoAmI,
          Tools::ListProjects,
          Tools::GetProject,
          Tools::SearchIssues,
          Tools::GetIssue,
          Tools::ListWikiPages,
          Tools::GetWikiPage,
          Tools::ListEnumerations,
          Tools::ListUsers,
          Tools::CreateIssue,
          Tools::AddIssueNote
        ]
      end

      # Tools this user may see. tools/list is permitted to vary by the
      # authorization on the request; the 2026-07-28 spec says so explicitly,
      # so a scope-narrowed token does not see tools it cannot call.
      def visible_to(user)
        all.select { |tool| tool.available_to?(user) }
      end

      def find(name, user)
        visible_to(user).detect { |tool| tool.mcp_name == name.to_s }
      end
    end
  end
end
