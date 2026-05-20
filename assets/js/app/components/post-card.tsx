import { useState } from "react";
import { UserAvatar } from "./user-avatar";
import { AckButton } from "./ack-button";
import { type FeedPost } from "../hooks/use-feed";
import { type OrgUser } from "../hooks/use-org-users";
import { useTranslation, type PostTranslation } from "../hooks/use-translation";
import { useCurrentUser } from "../contexts/current-user-context";

interface PostCardProps {
  post: FeedPost;
  author: OrgUser | undefined;
}

const LOCALE_LABEL: Record<string, string> = {
  en: "English",
  fi: "Finnish",
  pt: "Portuguese",
  es: "Spanish",
};


function TranslateIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M12.87 15.07l-2.54-2.51.03-.03A17.52 17.52 0 0014.07 6H17V4h-7V2H8v2H1v1.99h11.17C11.5 7.92 10.44 9.75 9 11.35 8.07 10.32 7.3 9.19 6.69 8H4.69c.73 1.63 1.73 3.17 2.98 4.56l-5.09 5.02L4 19l5-5 3.11 3.11.76-2.04zM18.5 10h-2L12 22h2l1.12-3h4.75L21 22h2l-4.5-12zm-2.62 7l1.62-4.33L19.12 17h-3.24z" />
    </svg>
  );
}

export function PostCard({ post, author }: PostCardProps) {
  const { currentUser } = useCurrentUser();
  const [translation, setTranslation] = useState<PostTranslation | null>(null);
  const [errored, setErrored] = useState(false);
  const translate = useTranslation();

  const canTranslate = Boolean(
    currentUser && currentUser.locale !== post.originalLocale,
  );
  const showingTranslation = translation !== null;
  const sourceLocaleLabel =
    LOCALE_LABEL[post.originalLocale] ?? post.originalLocale.toUpperCase();

  const title = showingTranslation ? translation.title : post.title;
  const body = showingTranslation ? translation.body : post.body;

  function handleTranslate() {
    if (!currentUser) return;
    setErrored(false);
    translate.mutate(
      { postId: post.id, targetLocale: currentUser.locale },
      {
        onSuccess: setTranslation,
        onError: () => setErrored(true),
      },
    );
  }

  return (
    <article className="bg-base-100 border border-base-content/10 rounded-2xl p-5 space-y-3 shadow-sm">
      <header className="flex items-start gap-3">
        <UserAvatar name={author?.name ?? "Unknown"} id={post.authorId} size="sm" />
        <div className="min-w-0 flex-1">
          <p className="text-sm font-medium truncate">{author?.name ?? "Unknown"}</p>
          <p className="text-xs text-base-content/50">
            {post.venueId ? <>venue post</> : <>org-wide</>}
          </p>
        </div>
        {canTranslate ? (
          <button
            type="button"
            disabled={translate.isPending}
            onClick={handleTranslate}
            title={
              showingTranslation
                ? "Translation shown"
                : translate.isPending
                ? "Translating…"
                : `Translate from ${sourceLocaleLabel}`
            }
            aria-label={`Translate from ${sourceLocaleLabel}`}
            className={`group shrink-0 p-1.5 rounded-md cursor-pointer transition-all duration-150 active:scale-90 ${
              showingTranslation
                ? "bg-base-content text-base-100 hover:bg-base-content/85"
                : "text-base-content/80 hover:text-base-content hover:bg-base-200"
            } disabled:opacity-50 disabled:cursor-progress disabled:active:scale-100`}
          >
            <TranslateIcon
              className={`w-5 h-5 transition-transform duration-200 group-hover:-rotate-12 ${
                translate.isPending ? "animate-pulse" : ""
              }`}
            />
          </button>
        ) : null}
      </header>

      <div>
        <h2 className="text-lg font-semibold tracking-tight">{title}</h2>
        <p className="mt-2 text-sm text-base-content/80 whitespace-pre-wrap">{body}</p>

        {showingTranslation ? (
          <p className="mt-2 text-xs text-base-content/50">
            Translated from {sourceLocaleLabel} ·{" "}
            <button
              type="button"
              onClick={() => setTranslation(null)}
              className="underline underline-offset-2 hover:text-base-content"
            >
              Show original
            </button>
          </p>
        ) : errored ? (
          <p className="mt-2 text-xs text-error" role="alert">
            Translation failed.{" "}
            <button
              type="button"
              onClick={handleTranslate}
              className="underline underline-offset-2"
            >
              Retry
            </button>
          </p>
        ) : null}
      </div>

      {post.requiresAcknowledgement ? (
        <footer className="flex items-center justify-between gap-3 text-xs text-base-content/60 pt-2 border-t border-base-content/5">
          <span>
            {post.ackCount} acknowledgement{post.ackCount === 1 ? "" : "s"}
          </span>
          <AckButton postId={post.id} acknowledged={post.acknowledgedByActor === true} />
        </footer>
      ) : null}
    </article>
  );
}
