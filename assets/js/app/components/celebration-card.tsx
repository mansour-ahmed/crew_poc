import { UserAvatar } from "./user-avatar";
import { type FeedCelebration } from "../hooks/use-feed";

interface CelebrationCardProps {
  celebration: FeedCelebration;
}

function yearsSince(iso: string): number {
  const start = new Date(iso);
  const now = new Date();
  let years = now.getUTCFullYear() - start.getUTCFullYear();
  const monthDelta = now.getUTCMonth() - start.getUTCMonth();
  if (monthDelta < 0 || (monthDelta === 0 && now.getUTCDate() < start.getUTCDate())) {
    years -= 1;
  }
  return years;
}

export function CelebrationCard({ celebration }: CelebrationCardProps) {
  const isBirthday = celebration.reason === "birthday";
  const years = isBirthday ? null : yearsSince(celebration.startedAt);

  return (
    <article className="bg-primary/5 border border-primary/20 rounded-2xl p-5 flex items-center gap-4">
      <div className="text-2xl" aria-hidden="true">
        {isBirthday ? "🎂" : "🎉"}
      </div>
      <UserAvatar name={celebration.name} id={celebration.id} size="md" />
      <div className="min-w-0">
        <p className="text-sm font-medium truncate">{celebration.name}</p>
        <p className="text-xs text-base-content/60">
          {isBirthday
            ? "is celebrating their birthday today"
            : `${years} year${years === 1 ? "" : "s"} at Crew today`}
        </p>
      </div>
    </article>
  );
}
