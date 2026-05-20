import { useMemo } from "react";
import { NavLink } from "react-router-dom";
import { useMyConversations, type ConversationSummary } from "../hooks/use-conversations";
import { useUnreadCounts } from "../hooks/use-memberships";

function groupConversations(conversations: ConversationSummary[]) {
  const venue: ConversationSummary[] = [];
  const shift: ConversationSummary[] = [];
  for (const c of conversations) {
    if (c.kind === "venue_channel") venue.push(c);
    else if (c.kind === "shift_channel") shift.push(c);
  }
  return { venue, shift };
}

interface RowProps {
  conversation: ConversationSummary;
  unread: number;
}

function Row({ conversation, unread }: RowProps) {
  return (
    <NavLink
      to={`/chat/${conversation.id}`}
      className={({ isActive }) =>
        `flex items-center justify-between px-4 py-2 text-sm rounded-md transition-colors ${isActive
          ? "bg-base-200 text-base-content"
          : "text-base-content/70 hover:bg-base-200/60"
        }`
      }
    >
      <span className="truncate">{conversation.title}</span>
      {unread > 0 ? (
        <span className="ml-2 inline-flex items-center justify-center min-w-5 h-5 px-1.5 text-xs font-medium rounded-full bg-primary text-primary-content">
          {unread}
        </span>
      ) : null}
    </NavLink>
  );
}

export function ConversationSidebar() {
  const conversationsQuery = useMyConversations();
  const membershipsQuery = useUnreadCounts();

  const unreadByConversation = useMemo(() => {
    const map = new Map<string, number>();
    for (const m of membershipsQuery.data ?? []) {
      map.set(m.conversationId, m.unreadCount ?? 0);
    }
    return map;
  }, [membershipsQuery.data]);

  const groups = useMemo(
    () => groupConversations(conversationsQuery.data ?? []),
    [conversationsQuery.data],
  );

  if (conversationsQuery.isLoading) {
    return (
      <div className="p-4 text-sm text-base-content/60">Loading…</div>
    );
  }

  if (!conversationsQuery.data?.length) {
    return (
      <div className="p-4 text-sm text-base-content/60">
        No conversations yet.
      </div>
    );
  }

  return (
    <nav className="p-3 space-y-6">
      {groups.venue.length > 0 ? (
        <div>
          <h2 className="px-4 pb-2 text-xs uppercase tracking-wide text-base-content/40">
            Venues
          </h2>
          <ul className="space-y-0.5">
            {groups.venue.map((c) => (
              <li key={c.id}>
                <Row
                  conversation={c}
                  unread={unreadByConversation.get(c.id) ?? 0}
                />
              </li>
            ))}
          </ul>
        </div>
      ) : null}

      {groups.shift.length > 0 ? (
        <div>
          <h2 className="px-4 pb-2 text-xs uppercase tracking-wide text-base-content/40">
            Shifts
          </h2>
          <ul className="space-y-0.5">
            {groups.shift.map((c) => (
              <li key={c.id}>
                <Row
                  conversation={c}
                  unread={unreadByConversation.get(c.id) ?? 0}
                />
              </li>
            ))}
          </ul>
        </div>
      ) : null}
    </nav>
  );
}
