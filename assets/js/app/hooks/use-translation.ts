import { useMutation } from "@tanstack/react-query";
import { ensurePostTranslation, type InferEnsurePostTranslationResult } from "../../ash_rpc";
import { fetchHeaders, unwrap, type Mutable } from "./chat-rpc";

const TRANSLATION_FIELDS = ["id", "postId", "targetLocale", "title", "body"] as const;

export type PostTranslation = InferEnsurePostTranslationResult<Mutable<typeof TRANSLATION_FIELDS>>;

export function useTranslation() {
  return useMutation<PostTranslation, Error, { postId: string; targetLocale: string }>({
    mutationFn: ({ postId, targetLocale }) =>
      unwrap(
        "translate post",
        ensurePostTranslation({
          input: { postId, targetLocale },
          fields: [...TRANSLATION_FIELDS],
          ...fetchHeaders(),
        }),
      ),
  });
}
