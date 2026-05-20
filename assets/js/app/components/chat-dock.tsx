import { useMemo } from "react";
import { Link } from "react-router-dom";
import { usePinnedConversations, type ConversationSummary } from "../hooks/use-conversations";
import { useUnreadCounts } from "../hooks/use-memberships";

function UnreadBadge({ count }: { count: number }) {
  if (count <= 0) return null;
  return (
    <span className="inline-flex items-center justify-center min-w-5 h-5 px-1.5 text-xs font-medium rounded-full bg-primary text-primary-content">
      {count}
    </span>
  );
}

function Row({
  conversation,
  unread,
}: {
  conversation: ConversationSummary;
  unread: number;
}) {
  return (
    <Link
      to={`/chat/${conversation.id}`}
      className="flex items-center justify-between gap-2 px-3 py-2 text-sm rounded-md text-base-content/70 hover:bg-base-200/60 transition-colors"
    >
      <span className="truncate">{conversation.title}</span>
      <UnreadBadge count={unread} />
    </Link>
  );
}

function Section({
  title,
  conversations,
  unreadByConversation,
}: {
  title: string;
  conversations: ConversationSummary[];
  unreadByConversation: Map<string, number>;
}) {
  if (conversations.length === 0) return null;
  return (
    <div>
      <h3 className="px-3 pb-1 text-xs uppercase tracking-wide text-base-content/40">
        {title}
      </h3>
      <ul className="space-y-0.5">
        {conversations.map((c) => (
          <li key={c.id}>
            <Row conversation={c} unread={unreadByConversation.get(c.id) ?? 0} />
          </li>
        ))}
      </ul>
    </div>
  );
}

export function ChatDock() {
  const { data: conversations = [], isLoading } = usePinnedConversations();
  const { data: memberships = [] } = useUnreadCounts();

  // Lookup map is consumed once per row; cache so we don't rebuild on each
  // render of an unrelated parent.
  const unreadByConversation = useMemo(() => {
    const map = new Map<string, number>();
    for (const m of memberships) map.set(m.conversationId, m.unreadCount ?? 0);
    return map;
  }, [memberships]);

  const venueConversations = conversations.filter((c) => c.kind === "venue_channel");
  const shiftConversations = conversations.filter((c) => c.kind === "shift_channel");
  const totalUnread = memberships.reduce((sum, m) => sum + (m.unreadCount ?? 0), 0);

  return (
    <section className="bg-base-100/90 backdrop-blur-sm border border-base-content/10 rounded-2xl shadow-sm flex flex-col">
      <div className="flex items-center justify-between px-5 py-3.5 border-b border-base-content/10">
        <div className="flex items-center gap-2">
          <h2 className="text-sm font-semibold tracking-tight">Reach out to your team</h2>
          <UnreadBadge count={totalUnread} />
        </div>
        <Link
          to="/chat"
          className="group text-xs font-medium text-base-content/80 hover:text-base-content underline underline-offset-2 decoration-base-content/30 hover:decoration-base-content transition-colors duration-150 inline-flex items-center gap-0.5"
        >
          Open chat
          <span aria-hidden="true" className="inline-block transition-transform duration-150 group-hover:translate-x-0.5">→</span>
        </Link>
      </div>

      <div className="px-2 py-4 space-y-7">
        {isLoading ? (
          <p className="px-3 text-sm text-base-content/60">Loading…</p>
        ) : conversations.length === 0 ? (
          <p className="px-3 text-sm text-base-content/60">Nothing pinned right now.</p>
        ) : (
          <>
            <Section
              title="Venues"
              conversations={venueConversations}
              unreadByConversation={unreadByConversation}
            />
            <Section
              title="Active shifts"
              conversations={shiftConversations}
              unreadByConversation={unreadByConversation}
            />
          </>
        )}
      </div>
    </section>
  );
}
