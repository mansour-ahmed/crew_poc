import { useEffect } from "react";
import {
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import {
  listConversationMemberships,
  markConversationRead,
  type InferListConversationMembershipsResult,
} from "../../ash_rpc";
import { UserNotifications } from "../lib/channels";
import { useSocket } from "../contexts/socket-context";
import { useCurrentUser } from "../contexts/current-user-context";
import { fetchHeaders, unwrap, type Mutable } from "./chat-rpc";

const MEMBERSHIP_FIELDS = [
  "id",
  "conversationId",
  "lastReadAt",
  "unreadCount",
] as const;

export type ConversationMembership =
  InferListConversationMembershipsResult<Mutable<typeof MEMBERSHIP_FIELDS>>[number];

const membershipsKey = (userId: string | undefined) =>
  ["chat", "memberships", userId] as const;

export function useUnreadCounts() {
  const { currentUser } = useCurrentUser();
  const socket = useSocket();
  const queryClient = useQueryClient();

  const query = useQuery<ConversationMembership[]>({
    queryKey: membershipsKey(currentUser?.id),
    enabled: Boolean(currentUser),
    queryFn: () =>
      unwrap(
        "load memberships",
        listConversationMemberships({
          fields: [...MEMBERSHIP_FIELDS],
          ...fetchHeaders(),
        }),
      ),
  });

  useEffect(() => {
    if (!socket || !currentUser) return;

    const channel = UserNotifications.create(socket, currentUser.id);
    channel.join();

    const ref = UserNotifications.on(channel, "unread_changed", () => {
      queryClient.invalidateQueries({ queryKey: membershipsKey(currentUser.id) });
    });

    return () => {
      channel.off("unread_changed", ref);
      channel.leave();
    };
  }, [socket, currentUser?.id, queryClient]);

  return query;
}

export function useMarkRead() {
  const queryClient = useQueryClient();
  const { currentUser } = useCurrentUser();

  return useMutation<unknown, Error, { membershipId: string }>({
    mutationFn: ({ membershipId }) =>
      unwrap(
        "mark read",
        markConversationRead({ identity: membershipId, ...fetchHeaders() }),
      ),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: membershipsKey(currentUser?.id) }),
  });
}
