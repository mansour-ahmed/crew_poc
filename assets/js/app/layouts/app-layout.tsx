import { Outlet } from "react-router-dom";
import { TopBar } from "../components/top-bar";
import { ChatDock } from "../components/chat-dock";

export function AppLayout() {
  return (
    <div className="min-h-screen bg-base-100 text-base-content">
      <TopBar />
      <ChatDock />
      <main className="max-w-6xl mx-auto px-6 lg:px-10 pt-6 lg:pt-16 pb-16 lg:pr-96">
        <Outlet />
      </main>
    </div>
  );
}
