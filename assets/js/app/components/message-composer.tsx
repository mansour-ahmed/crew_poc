import { useState } from "react";
import { useSendMessage } from "../hooks/use-messages";

interface MessageComposerProps {
  conversationId: string;
}

export function MessageComposer({ conversationId }: MessageComposerProps) {
  const [body, setBody] = useState("");
  const sendMessage = useSendMessage();

  const isPending = sendMessage.isPending;
  const canSend = body.trim().length > 0 && !isPending;

  function submit() {
    if (!canSend) return;
    sendMessage.mutate(
      { conversationId, body: body.trim() },
      { onSuccess: () => setBody("") },
    );
  }

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        submit();
      }}
      className="border-t border-base-content/10 px-6 py-4 flex flex-col gap-2"
    >
      <div className="flex items-end gap-3">
        <textarea
          value={body}
          onChange={(e) => setBody(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              submit();
            }
          }}
          rows={1}
          disabled={isPending}
          placeholder="Write a message…"
          className="textarea textarea-bordered flex-1 resize-none min-h-12 max-h-40"
        />
        <button type="submit" disabled={!canSend} className="btn btn-primary">
          Send
        </button>
      </div>

      {sendMessage.isError ? (
        <p className="text-xs text-error" role="alert">
          Couldn't send — try again.
        </p>
      ) : null}
    </form>
  );
}
