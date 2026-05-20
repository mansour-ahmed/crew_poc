import React, { createContext, useContext } from "react";
import { useQuery } from "@tanstack/react-query";
import {
  getCurrentUser,
  buildCSRFHeaders,
  type InferGetCurrentUserResult,
} from "../../ash_rpc";

const CURRENT_USER_FIELDS = [
  "id",
  "name",
  "email",
  "role",
  "locale",
  "organizationId",
] as const;

type Mutable<T extends readonly unknown[]> = [...T];

export type CurrentUser = InferGetCurrentUserResult<
  Mutable<typeof CURRENT_USER_FIELDS>
>;

interface CurrentUserContextValue {
  currentUser: CurrentUser | null;
  isLoading: boolean;
  refetch: () => void;
}

const CurrentUserContext = createContext<CurrentUserContextValue>({
  currentUser: null,
  isLoading: true,
  refetch: () => {},
});

async function fetchCurrentUser(): Promise<CurrentUser | null> {
  const result = await getCurrentUser({
    fields: [...CURRENT_USER_FIELDS],
    headers: buildCSRFHeaders(),
  });

  if (!result.success) return null;
  return result.data ?? null;
}

export function CurrentUserProvider({ children }: { children: React.ReactNode }) {
  const { data, isLoading, refetch } = useQuery({
    queryKey: ["current-user"],
    queryFn: fetchCurrentUser,
    staleTime: Infinity,
  });

  return (
    <CurrentUserContext.Provider
      value={{ currentUser: data ?? null, isLoading, refetch }}
    >
      {children}
    </CurrentUserContext.Provider>
  );
}

export function useCurrentUser() {
  return useContext(CurrentUserContext);
}
