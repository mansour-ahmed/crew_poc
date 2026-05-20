import React from "react";
import { NavLink } from "react-router-dom";
import { UserPicker } from "./user-picker";

interface NavLinkState {
  isActive: boolean;
}

function navLinkClass({ isActive }: NavLinkState): string {
  const base =
    "text-sm transition-colors duration-150 px-1 py-1 hover:text-base-content";
  return isActive
    ? `${base} text-base-content`
    : `${base} text-base-content/60`;
}

export function TopBar() {
  return (
    <header className="sticky top-0 z-30 bg-base-100/80 backdrop-blur-md">
      <div className="max-w-6xl mx-auto px-6 lg:px-10 h-16 flex items-center justify-between">
        <div className="flex items-center gap-10">
          <span className="font-bold text-base tracking-tight select-none inline-flex items-baseline gap-1">
            Crew
            <span
              aria-hidden="true"
              className="inline-block w-1.5 h-1.5 bg-base-content rotate-45 -translate-y-px"
            />
          </span>
          <nav className="flex items-center gap-7" aria-label="Main navigation">
            <NavLink to="/" end className={navLinkClass}>
              Feed
            </NavLink>
            <NavLink to="/chat" className={navLinkClass}>
              Chat
            </NavLink>
          </nav>
        </div>

        <UserPicker />
      </div>
    </header>
  );
}
