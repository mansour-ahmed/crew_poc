import { useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { listUsers, type InferListUsersResult } from "../../ash_rpc";
import { fetchHeaders, unwrap, type Mutable } from "./chat-rpc";
import { useCurrentUser } from "../contexts/current-user-context";

const USER_FIELDS = ["id", "name", "role", "jobTitle"] as const;

export type OrgUser = InferListUsersResult<Mutable<typeof USER_FIELDS>>[number];

export function useOrgUsers() {
  const { currentUser } = useCurrentUser();

  const query = useQuery<OrgUser[]>({
    queryKey: ["org-users", currentUser?.organizationId],
    enabled: Boolean(currentUser),
    queryFn: () =>
      unwrap(
        "load users",
        listUsers({ fields: [...USER_FIELDS], ...fetchHeaders() }),
      ),
  });

  const byId = useMemo(() => {
    const map = new Map<string, OrgUser>();
    for (const u of query.data ?? []) map.set(u.id, u);
    return map;
  }, [query.data]);

  return { ...query, byId };
}
