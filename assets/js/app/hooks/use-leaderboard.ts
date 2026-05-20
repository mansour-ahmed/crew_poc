import { useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { listShoutouts } from "../../ash_rpc";
import { fetchHeaders, unwrap } from "./chat-rpc";
import { useCurrentUser } from "../contexts/current-user-context";
import { useOrgUsers, type OrgUser } from "./use-org-users";

const LEADERBOARD_LIMIT = 3;

const FIELDS = ["id", "recipientId"] as const;

export interface LeaderboardEntry {
  user: OrgUser;
  count: number;
}

// Client-side aggregation: pull shoutouts, group by recipient, take top N.
// Only for PoC purposes, real implementation should use backend aggregation.
export function useLeaderboard() {
  const { currentUser } = useCurrentUser();
  const { byId } = useOrgUsers();

  const query = useQuery({
    queryKey: ["leaderboard", "shoutouts", currentUser?.organizationId],
    enabled: Boolean(currentUser),
    queryFn: () =>
      unwrap(
        "load shoutouts",
        listShoutouts({ fields: [...FIELDS], ...fetchHeaders() }),
      ),
  });

  const entries: LeaderboardEntry[] = useMemo(() => {
    if (!query.data) return [];
    const counts = new Map<string, number>();
    for (const s of query.data) {
      counts.set(s.recipientId, (counts.get(s.recipientId) ?? 0) + 1);
    }
    return Array.from(counts.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, LEADERBOARD_LIMIT)
      .map(([userId, count]) => {
        const user = byId.get(userId);
        return user ? { user, count } : null;
      })
      .filter((e): e is LeaderboardEntry => e !== null);
  }, [query.data, byId]);

  return { ...query, entries };
}
