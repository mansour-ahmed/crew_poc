import { ChatDock } from "./chat-dock";
import { LeaderboardCard } from "./leaderboard-card";

export function RightRail() {
  return (
    <div className="space-y-4 mx-6 mt-6 lg:mx-0 lg:mt-0 lg:fixed lg:top-20 lg:right-6 lg:w-80 lg:max-h-[calc(100vh-6rem)] lg:overflow-y-auto">
      <ChatDock />
      <LeaderboardCard />
    </div>
  );
}
