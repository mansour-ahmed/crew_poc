import React, { useEffect, useRef, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { UserAvatar } from "./user-avatar";
import { useCurrentUser } from "../contexts/current-user-context";
import {
  listUsers,
  buildCSRFHeaders,
  type InferListUsersResult,
} from "../../ash_rpc";
import { switchUser as switchUserRequest } from "../../routes";

const USER_LIST_FIELDS = ["id", "name", "role", "organizationId"] as const;

type Mutable<T extends readonly unknown[]> = [...T];

type UserSummary = InferListUsersResult<
  Mutable<typeof USER_LIST_FIELDS>
> extends Array<infer Item>
  ? Item
  : never;

async function fetchUsers(): Promise<UserSummary[]> {
  const result = await listUsers({
    fields: [...USER_LIST_FIELDS],
    sort: "name",
    headers: buildCSRFHeaders(),
  });

  if (!result.success) return [];
  return result.data;
}

async function switchUser(userId: string): Promise<void> {
  const response = await switchUserRequest(
    { userId },
    { headers: buildCSRFHeaders() },
  );

  if (response.ok) {
    window.location.reload();
  }
}

export function UserPicker() {
  const { currentUser } = useCurrentUser();
  const [open, setOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  const { data: users = [] } = useQuery({
    queryKey: ["users", "list"],
    queryFn: fetchUsers,
    staleTime: 60_000,
  });

  useEffect(() => {
    if (!open) return;

    const handleClickOutside = (event: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setOpen(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, [open]);

  return (
    <div className="relative" ref={containerRef}>
      <button
        className="flex items-center gap-2 rounded-full border border-base-content/10 bg-base-200 hover:bg-base-300 pl-1 pr-3 py-1 text-sm transition-colors duration-150"
        onClick={() => setOpen((previous) => !previous)}
        tabIndex={0}
        aria-haspopup="listbox"
        aria-expanded={open}
      >
        {currentUser ? (
          <>
            <UserAvatar name={currentUser.name} id={currentUser.id} size="sm" />
            <span className="hidden sm:inline max-w-32 truncate">{currentUser.name}</span>
          </>
        ) : (
          <span className="px-2 text-base-content/60">Hi, I'm…</span>
        )}
        <svg
          className={`w-3.5 h-3.5 text-base-content/60 transition-transform duration-200 ${open ? "rotate-180" : ""}`}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {open && (
        <ul
          className="absolute right-0 top-full mt-2 z-50 p-1.5 shadow-2xl shadow-black/40 bg-base-200 rounded-xl w-64 border border-base-content/10"
          role="listbox"
        >
          {users.length === 0 ? (
            <li className="py-2 px-3 text-sm text-base-content/50">One sec…</li>
          ) : (
            users.map((user) => (
              <li key={user.id}>
                <button
                  className={`flex items-center gap-3 w-full text-left rounded-lg px-2 py-2 transition-colors duration-100 hover:bg-base-300 ${
                    currentUser?.id === user.id ? "bg-base-300" : ""
                  }`}
                  onClick={() => switchUser(user.id)}
                  role="option"
                  aria-selected={currentUser?.id === user.id}
                >
                  <UserAvatar name={user.name} id={user.id} size="sm" />
                  <div className="min-w-0 flex-1">
                    <div className="text-sm font-medium truncate">{user.name}</div>
                    <div className="text-xs text-base-content/50 capitalize">{user.role}</div>
                  </div>
                  {currentUser?.id === user.id && (
                    <svg
                      className="w-3.5 h-3.5 ml-auto text-accent flex-shrink-0"
                      fill="currentColor"
                      viewBox="0 0 20 20"
                      aria-label="Current user"
                    >
                      <path
                        fillRule="evenodd"
                        d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                        clipRule="evenodd"
                      />
                    </svg>
                  )}
                </button>
              </li>
            ))
          )}
        </ul>
      )}
    </div>
  );
}
