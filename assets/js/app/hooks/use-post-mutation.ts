import { useMutation, useQueryClient } from "@tanstack/react-query";
import { createPost, createShoutout, type CreatePostInput, type CreateShoutoutInput } from "../../ash_rpc";
import { fetchHeaders, unwrap } from "./chat-rpc";
import { useCurrentUser } from "../contexts/current-user-context";
import { useToast } from "../contexts/toast-context";

export function usePostMutation() {
  const queryClient = useQueryClient();
  const { currentUser } = useCurrentUser();
  const { showToast } = useToast();

  return useMutation<unknown, Error, CreatePostInput>({
    mutationFn: (input) =>
      unwrap("create post", createPost({ input, ...fetchHeaders() })),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["feed", currentUser?.id] });
      showToast();
    },
  });
}

export function useShoutoutMutation() {
  const queryClient = useQueryClient();
  const { currentUser } = useCurrentUser();
  const { showToast } = useToast();

  return useMutation<unknown, Error, CreateShoutoutInput>({
    mutationFn: (input) =>
      unwrap("create shoutout", createShoutout({ input, ...fetchHeaders() })),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["feed", currentUser?.id] });
      showToast();
    },
  });
}
