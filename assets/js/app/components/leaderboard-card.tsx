import { UserAvatar } from "./user-avatar";
import { useLeaderboard } from "../hooks/use-leaderboard";

export function LeaderboardCard() {
  const { entries, isLoading } = useLeaderboard();

  if (!isLoading && entries.length === 0) return null;

  return (
    <section className="bg-base-100/90 backdrop-blur-sm border border-base-content/10 rounded-2xl shadow-sm">
      <div className="px-5 py-3.5 border-b border-base-content/10">
        <h2 className="text-sm font-semibold tracking-tight">Most praised</h2>
      </div>

      <ol className="px-2 py-3 space-y-1">
        {isLoading ? (
          <p className="px-3 text-sm text-base-content/60">Loading…</p>
        ) : (
          entries.map((entry, index) => (
            <li
              key={entry.user.id}
              className="flex items-center gap-3 px-3 py-2 rounded-md"
            >
              <span className="text-xs tabular-nums text-base-content/40 w-4 text-right">
                {index + 1}
              </span>
              <UserAvatar name={entry.user.name} id={entry.user.id} size="sm" />
              <div className="min-w-0 flex-1">
                <p className="text-sm truncate">{entry.user.name}</p>
              </div>
              <span className="inline-flex items-center justify-center min-w-5 h-5 px-1.5 text-xs font-medium rounded-full bg-secondary/15 text-secondary">
                {entry.count}
              </span>
            </li>
          ))
        )}
      </ol>
    </section>
  );
}
