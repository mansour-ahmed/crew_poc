import { Link } from "react-router-dom";
import { useCurrentUser } from "../contexts/current-user-context";
import { UserAvatar } from "../components/user-avatar";
import { useFeed } from "../hooks/use-feed";
import { useOrgUsers } from "../hooks/use-org-users";
import { PostCard } from "../components/post-card";
import { ShoutoutCard } from "../components/shoutout-card";
import { CelebrationCard } from "../components/celebration-card";
import { LOCALE_LABEL } from "../lib/locales";

export function FeedPage() {
  const { currentUser, isLoading: isCurrentUserLoading } = useCurrentUser();
  const { data: feed, isLoading: isFeedLoading } = useFeed();
  const { byId: usersById } = useOrgUsers();

  if (isCurrentUserLoading) {
    return (
      <div className="flex justify-center py-24">
        <span className="loading loading-spinner loading-md opacity-60" aria-label="Loading…" />
      </div>
    );
  }

  if (!currentUser) {
    return (
      <div className="max-w-2xl">
        <h1 className="text-5xl sm:text-6xl font-semibold tracking-tight leading-[1.05]">
          Hey there.<br />Good to see you.
        </h1>
        <p className="mt-6 text-lg text-base-content/60 max-w-lg">
          Let us know who you are from up top, and we'll get everything ready for you.
        </p>
      </div>
    );
  }

  const localeName = currentUser.locale
    ? (LOCALE_LABEL[currentUser.locale] ?? currentUser.locale)
    : "—";

  return (
    <div className="space-y-10 max-w-2xl">
      <div className="flex flex-col sm:flex-row sm:items-center gap-5">
        <div className="flex items-center gap-5 flex-1 min-w-0">
          <UserAvatar name={currentUser.name} id={currentUser.id} size="lg" />
          <div className="min-w-0 flex-1">
            <p className="inline-flex items-center gap-2 text-xs font-medium uppercase tracking-[0.14em] text-secondary mb-2">
              <span aria-hidden="true" className="inline-block w-1.5 h-1.5 bg-accent rotate-45" />
              Your feed
            </p>
            <h1 className="text-3xl font-semibold tracking-tight truncate">
              Hey, {currentUser.name.split(" ")[0]}.
            </h1>
            <p className="text-sm text-base-content/60 capitalize mt-1">
              {currentUser.role} · {localeName}
            </p>
          </div>
        </div>
        <div className="flex gap-2 shrink-0">
          <Link
            to="/posts/new"
            className="btn btn-sm btn-primary flex-1 sm:flex-none shadow-sm transition-all duration-150 hover:-translate-y-0.5 hover:shadow-md active:translate-y-0 active:scale-95"
          >
            + New post
          </Link>
          <Link
            to="/shoutouts/new"
            className="btn btn-sm btn-secondary flex-1 sm:flex-none shadow-sm transition-all duration-150 hover:-translate-y-0.5 hover:shadow-md active:translate-y-0 active:scale-95"
          >
            Send shoutout
          </Link>
        </div>
      </div>

      <div className="space-y-4">
        {isFeedLoading ? (
          <div className="text-sm text-base-content/50">Loading feed…</div>
        ) : !feed?.length ? (
          <div className="text-sm text-base-content/50">
            Nothing in the feed yet. Be the first to post something.
          </div>
        ) : (
          feed.map((entry) => {
            switch (entry.kind) {
              case "post":
                return (
                  <PostCard
                    key={`post:${entry.item.id}`}
                    post={entry.item}
                    author={usersById.get(entry.item.authorId)}
                  />
                );
              case "shoutout":
                return (
                  <ShoutoutCard
                    key={`shoutout:${entry.item.id}`}
                    shoutout={entry.item}
                    sender={usersById.get(entry.item.senderId)}
                    recipient={usersById.get(entry.item.recipientId)}
                  />
                );
              case "celebration":
                return (
                  <CelebrationCard
                    key={`celebration:${entry.item.id}`}
                    celebration={entry.item}
                  />
                );
            }
          })
        )}
      </div>
    </div>
  );
}
