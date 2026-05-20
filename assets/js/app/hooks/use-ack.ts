import { useMutation, useQueryClient } from "@tanstack/react-query";
import { createAcknowledgement } from "../../ash_rpc";
import { fetchHeaders, unwrap } from "./chat-rpc";
import { useCurrentUser } from "../contexts/current-user-context";
import { useToast } from "../contexts/toast-context";
import { type FeedItem } from "./use-feed";

// Optimistically flips `acknowledgedByActor` to true and bumps `ackCount` on the
// matching post in the feed cache. The eventual `acknowledgement_added`
// broadcast (Phase C) will refresh the canonical numbers.
export function useAck() {
  const queryClient = useQueryClient();
  const { currentUser } = useCurrentUser();
  const { showToast } = useToast();
  const feedKey = ["feed", currentUser?.id] as const;

  return useMutation<unknown, Error, { postId: string }, { previous: FeedItem[] | undefined }>({
    mutationFn: ({ postId }) =>
      unwrap(
        "acknowledge post",
        createAcknowledgement({ input: { postId }, ...fetchHeaders() }),
      ),
    onMutate: async ({ postId }) => {
      await queryClient.cancelQueries({ queryKey: feedKey });
      const previous = queryClient.getQueryData<FeedItem[]>(feedKey);

      queryClient.setQueryData<FeedItem[]>(feedKey, (current) =>
        current?.map((entry) => {
          if (entry.kind !== "post" || entry.item.id !== postId) return entry;
          return {
            ...entry,
            item: {
              ...entry.item,
              acknowledgedByActor: true,
              ackCount: (entry.item.ackCount ?? 0) + 1,
            },
          };
        }),
      );

      return { previous };
    },
    onError: (_err, _vars, context) => {
      if (context?.previous) queryClient.setQueryData(feedKey, context.previous);
    },
    onSuccess: () => {
      showToast();
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: feedKey });
    },
  });
}
