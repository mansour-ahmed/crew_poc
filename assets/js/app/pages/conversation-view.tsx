import { useEffect } from "react";
import { Link, useParams } from "react-router-dom";
import { useMyConversations } from "../hooks/use-conversations";
import { useUnreadCounts, useMarkRead } from "../hooks/use-memberships";
import { useMessages } from "../hooks/use-messages";
import { useCurrentUser } from "../contexts/current-user-context";
import { MessageList } from "../components/message-list";
import { MessageComposer } from "../components/message-composer";

export function ConversationView() {
  const { conversationId } = useParams<{ conversationId: string }>();
  const { currentUser } = useCurrentUser();
  const conversationsQuery = useMyConversations();
  const membershipsQuery = useUnreadCounts();
  const messagesQuery = useMessages(conversationId);
  const markRead = useMarkRead();

  const conversation = conversationsQuery.data?.find(
    (c) => c.id === conversationId,
  );
  const membership = membershipsQuery.data?.find(
    (m) => m.conversationId === conversationId,
  );

  useEffect(() => {
    if (!membership) return;
    if (membership.unreadCount && membership.unreadCount > 0) {
      markRead.mutate({ membershipId: membership.id });
    }
  }, [membership?.id, membership?.unreadCount]);

  if (!conversationId || !currentUser) return null;

  if (conversationsQuery.isLoading || messagesQuery.isLoading) {
    return (
      <div className="flex-1 flex items-center justify-center text-sm text-base-content/50">
        Loading…
      </div>
    );
  }

  if (!conversation) {
    return (
      <div className="flex-1 flex items-center justify-center text-sm text-base-content/50">
        Conversation not found, or you're not a member.
      </div>
    );
  }

  return (
    <div className="flex-1 flex flex-col min-h-0">
      <header className="px-6 py-4 border-b border-base-content/10 flex items-center gap-3">
        <Link
          to="/chat"
          aria-label="Back to conversations"
          className="lg:hidden text-base-content/60 hover:text-base-content text-lg leading-none transition-all duration-150 hover:-translate-x-0.5"
        >
          ←
        </Link>
        <div className="min-w-0">
          <h1 className="text-base font-semibold truncate">{conversation.title}</h1>
          <p className="text-xs text-base-content/50 capitalize mt-0.5">
            {conversation.kind === "venue_channel" ? "Venue channel" : "Shift channel"}
          </p>
        </div>
      </header>

      <MessageList messages={messagesQuery.data ?? []} currentUserId={currentUser.id} />

      <MessageComposer conversationId={conversationId} />
    </div>
  );
}

export function ChatIndex() {
  return (
    <div className="flex-1 flex items-center justify-center text-sm text-base-content/50">
      Pick a conversation from the sidebar to get started.
    </div>
  );
}
