import { Link } from "react-router-dom";
import { UserPicker } from "./user-picker";

export function TopBar() {
  return (
    <header className="sticky top-0 z-30 bg-base-100/80 backdrop-blur-md">
      <div className="max-w-6xl mx-auto px-6 lg:px-10 h-16 flex items-center justify-between">
        <Link to="/" className="font-bold text-base tracking-tight select-none inline-flex items-baseline gap-1">
          Crew
          <span
            aria-hidden="true"
            className="inline-block w-1.5 h-1.5 bg-secondary rotate-45 -translate-y-px"
          />
        </Link>

        <UserPicker />
      </div>
    </header>
  );
}
