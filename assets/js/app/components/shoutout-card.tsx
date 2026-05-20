import { UserAvatar } from "./user-avatar";
import { type FeedShoutout } from "../hooks/use-feed";
import { type OrgUser } from "../hooks/use-org-users";

interface ShoutoutCardProps {
  shoutout: FeedShoutout;
  sender: OrgUser | undefined;
  recipient: OrgUser | undefined;
}

export function ShoutoutCard({ shoutout, sender, recipient }: ShoutoutCardProps) {
  return (
    <article className="bg-base-100 border-2 border-dotted border-secondary/40 rounded-2xl p-5 space-y-3">
      <header className="flex items-center gap-3 text-sm">
        <UserAvatar name={sender?.name ?? "?"} id={shoutout.senderId} size="sm" />
        <span className="text-base-content/70">
          <span className="font-medium text-base-content">{sender?.name ?? "Someone"}</span>{" "}
          gave a shoutout to{" "}
          <span className="font-medium text-base-content">{recipient?.name ?? "someone"}</span>
          <span aria-hidden="true" className="ml-1">🎉</span>
        </span>
      </header>

      <blockquote className="relative pl-10 pr-2 text-base-content/80 italic whitespace-pre-wrap">
        <svg
          className="absolute left-0 top-0 w-7 h-7 text-secondary/50"
          viewBox="0 0 24 24"
          fill="currentColor"
          aria-hidden="true"
        >
          <path d="M7.17 17q-.825 0-1.412-.587T5.17 15v-3q0-1.825 1.288-3.112T9.57 7.6v2.025q-1 .25-1.625 1.025T7.32 12.5h.65q.825 0 1.413.588T9.97 14.5V15q0 .825-.587 1.412T7.97 17zm9 0q-.825 0-1.412-.587T14.17 15v-3q0-1.825 1.288-3.112T18.57 7.6v2.025q-1 .25-1.625 1.025t-.625 1.85h.65q.825 0 1.413.588t.587 1.412V15q0 .825-.587 1.412T16.97 17z" />
        </svg>
        {shoutout.body}
      </blockquote>
    </article>
  );
}
