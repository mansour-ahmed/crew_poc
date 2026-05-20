import { useEffect } from "react";
import {
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import {
  listMessagesForConversation,
  sendMessage,
  type InferListMessagesForConversationResult,
  type InferSendMessageResult,
} from "../../ash_rpc";
import { ChatConversation } from "../lib/channels";
import { useSocket } from "../contexts/socket-context";
import { fetchHeaders, unwrap, type Mutable } from "./chat-rpc";

const MESSAGE_FIELDS = [
  "id",
  "conversationId",
  "authorId",
  "authorName",
  "body",
  "insertedAt",
] as const;

export type ChatMessage = InferListMessagesForConversationResult<
  Mutable<typeof MESSAGE_FIELDS>
>[number];

const messagesKey = (conversationId: string) =>
  ["chat", "messages", conversationId] as const;

function appendUnique(existing: ChatMessage[] | undefined, msg: ChatMessage) {
  if (!existing) return [msg];
  if (existing.some((m) => m.id === msg.id)) return existing;
  return [...existing, msg];
}

export function useMessages(conversationId: string | undefined) {
  const socket = useSocket();
  const queryClient = useQueryClient();

  const query = useQuery<ChatMessage[]>({
    queryKey: ["chat", "messages", conversationId ?? "none"],
    enabled: Boolean(conversationId),
    queryFn: () =>
      conversationId
        ? unwrap(
            "load messages",
            listMessagesForConversation({
              input: { conversationId },
              fields: [...MESSAGE_FIELDS],
              ...fetchHeaders(),
            }),
          )
        : Promise.resolve([]),
  });

  useEffect(() => {
    if (!socket || !conversationId) return;

    const channel = ChatConversation.create(socket, conversationId);
    channel.join();

    const ref = ChatConversation.on(channel, "message_created", (incoming) => {
      queryClient.setQueryData<ChatMessage[]>(
        messagesKey(conversationId),
        (existing) => appendUnique(existing, incoming),
      );
    });

    return () => {
      channel.off("message_created", ref);
      channel.leave();
    };
  }, [socket, conversationId, queryClient]);

  return query;
}

export function useSendMessage() {
  return useMutation<
    InferSendMessageResult<Mutable<typeof MESSAGE_FIELDS>>,
    Error,
    { conversationId: string; body: string }
  >({
    mutationFn: ({ conversationId, body }) =>
      unwrap(
        "send message",
        sendMessage({
          input: { conversationId, body },
          fields: [...MESSAGE_FIELDS],
          ...fetchHeaders(),
        }),
      ),
  });
}
