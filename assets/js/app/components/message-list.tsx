import React, { useEffect, useRef } from "react";
import { type ChatMessage } from "../hooks/use-messages";
import { UserAvatar } from "./user-avatar";

interface MessageListProps {
  messages: ChatMessage[];
  currentUserId: string;
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString(undefined, {
    hour: "numeric",
    minute: "2-digit",
  });
}

export function MessageList({ messages, currentUserId }: MessageListProps) {
  const endRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages.length]);

  if (messages.length === 0) {
    return (
      <div className="flex-1 flex items-center justify-center text-sm text-base-content/50">
        Be the first to say something.
      </div>
    );
  }

  return (
    <div className="flex-1 overflow-y-auto px-6 py-6 space-y-4">
      {messages.map((m) => {
        const isMine = m.authorId === currentUserId;
        return (
          <div
            key={m.id}
            className={`flex items-end gap-3 ${
              isMine ? "flex-row-reverse" : ""
            }`}
          >
            <UserAvatar name={m.authorId} id={m.authorId} size="sm" />
            <div className={`max-w-md ${isMine ? "items-end" : ""}`}>
              <div
                className={`px-4 py-2 rounded-2xl text-sm whitespace-pre-wrap break-words ${
                  isMine
                    ? "bg-primary text-primary-content rounded-br-md"
                    : "bg-base-200 text-base-content rounded-bl-md"
                }`}
              >
                {m.body}
              </div>
              <div
                className={`mt-1 text-xs text-base-content/40 ${
                  isMine ? "text-right" : "text-left"
                }`}
              >
                {formatTime(m.insertedAt)}
              </div>
            </div>
          </div>
        );
      })}
      <div ref={endRef} />
    </div>
  );
}
