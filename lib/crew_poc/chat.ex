defmodule CrewPoc.Chat do
  use Ash.Domain,
    otp_app: :crew_poc,
    extensions: [AshTypescript.Rpc]

  typescript_rpc do
    resource CrewPoc.Chat.Conversation do
      rpc_action :list_conversations, :read
      rpc_action :list_pinned_conversations, :list_pinned
    end

    resource CrewPoc.Chat.ConversationMembership do
      rpc_action :list_conversation_memberships, :read
      rpc_action :mark_conversation_read, :mark_read
    end

    resource CrewPoc.Chat.Message do
      rpc_action :list_messages, :read
      rpc_action :list_messages_for_conversation, :list_for_conversation
      rpc_action :send_message, :create
    end
  end

  resources do
    resource CrewPoc.Chat.Conversation do
      define :create_venue_conversation, action: :create_venue_conversation, args: [:venue_id]
      define :create_shift_conversation, action: :create_shift_conversation, args: [:shift_id]
      define :get_conversation, action: :read, get_by: [:id]
      define :list_conversations, action: :read
      define :list_pinned_conversations, action: :list_pinned
    end

    resource CrewPoc.Chat.ConversationMembership do
      define :create_conversation_membership, action: :create
      define :destroy_conversation_membership, action: :destroy
      define :list_conversation_memberships, action: :read
      define :mark_conversation_read, action: :mark_read
    end

    resource CrewPoc.Chat.Message do
      define :list_messages, action: :read

      define :list_messages_for_conversation,
        action: :list_for_conversation,
        args: [:conversation_id]

      define :send_message, action: :create
    end
  end
end
