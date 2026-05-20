import React from "react";
import { useCurrentUser } from "../contexts/current-user-context";
import { UserAvatar } from "../components/user-avatar";

const LOCALE_LABELS: Record<string, string> = {
  fi: "Finnish",
  pt: "Portuguese",
  es: "Spanish",
};

export function FeedPage() {
  const { currentUser, isLoading } = useCurrentUser();

  if (isLoading) {
    return (
      <div className="flex justify-center py-24">
        <span className="loading loading-spinner loading-md opacity-60" aria-label="Loading…" />
      </div>
    );
  }

  if (!currentUser) {
    return (
      <div className="max-w-2xl">
        <h1 className="text-5xl sm:text-6xl font-semibold tracking-tight leading-[1.05]">
          Hey there.<br />Good to see you.
        </h1>
        <p className="mt-6 text-lg text-base-content/60 max-w-lg">
          Let us know who you are from up top, and we'll get everything ready for you.
        </p>
      </div>
    );
  }

  const localeName = currentUser.locale
    ? (LOCALE_LABELS[currentUser.locale] ?? currentUser.locale)
    : "—";

  const firstName = currentUser.name.split(" ")[0];

  return (
    <div className="space-y-10">
      <div className="flex items-center gap-5">
        <UserAvatar name={currentUser.name} id={currentUser.id} size="lg" />
        <div className="min-w-0">
          <h1 className="text-3xl font-semibold tracking-tight truncate">
            Hey, {firstName}.
          </h1>
          <p className="text-sm text-base-content/60 capitalize mt-1">
            {currentUser.role} · {localeName}
          </p>
        </div>
      </div>

      <div className="border-t border-base-content/10 pt-10">
        <p className="text-base-content/60">
          We're still putting your feed together. Thanks for your patience — we'll have something good for you soon.
        </p>
      </div>
    </div>
  );
}
