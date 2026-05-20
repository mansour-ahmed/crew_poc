import { useQuery } from "@tanstack/react-query";
import {
  celebratingToday,
  listPosts,
  listShoutouts,
  type InferCelebratingTodayResult,
  type InferListPostsResult,
  type InferListShoutoutsResult,
} from "../../ash_rpc";
import { fetchHeaders, unwrap, type Mutable } from "./chat-rpc";
import { useCurrentUser } from "../contexts/current-user-context";

// ── Field selections ──────────────────────────────────────

const POST_FIELDS = [
  "id",
  "title",
  "body",
  "originalLocale",
  "requiresAcknowledgement",
  "authorId",
  "venueId",
  "ackCount",
  "acknowledgedByActor",
  "insertedAt",
] as const;

const SHOUTOUT_FIELDS = [
  "id",
  "senderId",
  "recipientId",
  "body",
  "insertedAt",
] as const;

// User celebration calcs aren't exposed as public booleans, so load the dates
// and derive birthday-vs-anniversary client-side.
const CELEBRATION_FIELDS = [
  "id",
  "name",
  "role",
  "birthday",
  "startedAt",
] as const;

export type FeedPost = InferListPostsResult<Mutable<typeof POST_FIELDS>>[number];
export type FeedShoutout = InferListShoutoutsResult<Mutable<typeof SHOUTOUT_FIELDS>>[number];
export type FeedCelebrationUser = InferCelebratingTodayResult<
  Mutable<typeof CELEBRATION_FIELDS>
>[number];

export type FeedCelebration = FeedCelebrationUser & {
  /** "birthday" if today is the user's birthday, "anniversary" otherwise. */
  reason: "birthday" | "anniversary";
};

// ── Discriminated union ────────────────────────────────────

export type FeedItem =
  | { kind: "post"; item: FeedPost; timestamp: string }
  | { kind: "shoutout"; item: FeedShoutout; timestamp: string }
  | { kind: "celebration"; item: FeedCelebration; timestamp: string };

function sameMonthDay(iso: string, now: Date): boolean {
  if (!iso) return false;
  const d = new Date(iso);
  return d.getUTCMonth() === now.getUTCMonth() && d.getUTCDate() === now.getUTCDate();
}

function celebrationReason(user: FeedCelebrationUser): FeedCelebration["reason"] {
  const now = new Date();
  return sameMonthDay(user.birthday, now) ? "birthday" : "anniversary";
}

// Celebrations don't have a real timestamp — anchor them to start-of-day UTC so
// they sort alongside anything posted today, just below newer items.
function startOfDayUtcIso(): string {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())).toISOString();
}

// ── Hook ───────────────────────────────────────────────────

const FEED_LIMIT = 30;

export function useFeed() {
  const { currentUser } = useCurrentUser();

  return useQuery<FeedItem[]>({
    queryKey: ["feed", currentUser?.id],
    enabled: Boolean(currentUser),
    queryFn: async () => {
      const [posts, shoutouts, celebrationUsers] = await Promise.all([
        unwrap(
          "load posts",
          listPosts({ fields: [...POST_FIELDS], sort: "-insertedAt", ...fetchHeaders() }),
        ),
        unwrap(
          "load shoutouts",
          listShoutouts({ fields: [...SHOUTOUT_FIELDS], sort: "-insertedAt", ...fetchHeaders() }),
        ),
        unwrap(
          "load celebrations",
          celebratingToday({ fields: [...CELEBRATION_FIELDS], ...fetchHeaders() }),
        ),
      ]);

      const celebrationTimestamp = startOfDayUtcIso();

      const items: FeedItem[] = [
        ...posts.map((item) => ({
          kind: "post" as const,
          item,
          timestamp: item.insertedAt,
        })),
        ...shoutouts.map((item) => ({
          kind: "shoutout" as const,
          item,
          timestamp: item.insertedAt,
        })),
        ...celebrationUsers.map((user) => ({
          kind: "celebration" as const,
          item: { ...user, reason: celebrationReason(user) },
          timestamp: celebrationTimestamp,
        })),
      ];

      items.sort((a, b) => b.timestamp.localeCompare(a.timestamp));

      return items.slice(0, FEED_LIMIT);
    },
  });
}
