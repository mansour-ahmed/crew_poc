import { Outlet } from "react-router-dom";
import { TopBar } from "../components/top-bar";
import { RightRail } from "../components/right-rail";

export function AppLayout() {
  return (
    <div className="min-h-screen bg-base-100 text-base-content">
      <TopBar />
      <RightRail />
      <main className="max-w-6xl mx-auto px-6 lg:px-10 pt-6 lg:pt-16 pb-16 lg:pr-96">
        <Outlet />
      </main>
    </div>
  );
}
