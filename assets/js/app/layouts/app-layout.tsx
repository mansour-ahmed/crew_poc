import React from "react";
import { Outlet } from "react-router-dom";
import { TopBar } from "../components/top-bar";

export function AppLayout() {
  return (
    <div className="min-h-screen bg-base-100 text-base-content">
      <TopBar />
      <main className="max-w-6xl mx-auto px-6 lg:px-10 py-16">
        <Outlet />
      </main>
    </div>
  );
}
