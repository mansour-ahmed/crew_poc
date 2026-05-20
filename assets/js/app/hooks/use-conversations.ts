import { useQuery } from "@tanstack/react-query";
import {
  listConversations,
  listPinnedConversations,
  type InferListConversationsResult,
} from "../../ash_rpc";
import { useCurrentUser } from "../contexts/current-user-context";
import { fetchHeaders, unwrap, type Mutable } from "./chat-rpc";

const CONVERSATION_FIELDS = ["id", "kind", "title", "venueId", "shiftId"] as const;

export type ConversationSummary = InferListConversationsResult<
  Mutable<typeof CONVERSATION_FIELDS>
>[number];

export function useMyConversations() {
  const { currentUser } = useCurrentUser();
  return useQuery<ConversationSummary[]>({
    queryKey: ["chat", "conversations", currentUser?.id],
    enabled: Boolean(currentUser),
    queryFn: () =>
      unwrap(
        "load conversations",
        listConversations({ fields: [...CONVERSATION_FIELDS], ...fetchHeaders() }),
      ),
  });
}

export function usePinnedConversations() {
  const { currentUser } = useCurrentUser();
  return useQuery<ConversationSummary[]>({
    queryKey: ["chat", "pinned-conversations", currentUser?.id],
    enabled: Boolean(currentUser),
    queryFn: () =>
      unwrap(
        "load pinned conversations",
        listPinnedConversations({ fields: [...CONVERSATION_FIELDS], ...fetchHeaders() }),
      ),
  });
}
