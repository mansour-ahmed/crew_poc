import type { ChatConversationChannel, ChatConversationChannelEvents, ChatConversationChannelHandlers, ChatConversationChannelRefs, UserNotificationsChannel, UserNotificationsChannelEvents, UserNotificationsChannelHandlers, UserNotificationsChannelRefs } from "./ash_types";
export type * from "./ash_types";

export function createChatConversationChannel(
  socket: { channel(topic: string, params?: object): unknown },
  suffix: string
): ChatConversationChannel {
  return socket.channel(`chat:conversation:${suffix}`) as ChatConversationChannel;
}

export function onChatConversationChannelMessage<E extends keyof ChatConversationChannelEvents>(
  channel: ChatConversationChannel,
  event: E,
  handler: (payload: ChatConversationChannelEvents[E]) => void
): number {
  return channel.on(event, (payload: unknown) => handler(payload as ChatConversationChannelEvents[E]));
}

export function onChatConversationChannelMessages(
  channel: ChatConversationChannel,
  handlers: ChatConversationChannelHandlers
): ChatConversationChannelRefs {
  const refs: ChatConversationChannelRefs = {};
  for (const event in handlers) {
    const e = event as keyof ChatConversationChannelEvents;
    const handler = handlers[e];
    if (handler) {
      refs[e] = channel.on(event, (payload) => (handler as (p: unknown) => void)(payload));
    }
  }
  return refs;
}

export function unsubscribeChatConversationChannel(
  channel: ChatConversationChannel,
  refs: ChatConversationChannelRefs
): void {
  for (const event in refs) {
    const e = event as keyof ChatConversationChannelRefs;
    const ref = refs[e];
    if (ref !== undefined) {
      channel.off(event, ref);
    }
  }
}

export function createUserNotificationsChannel(
  socket: { channel(topic: string, params?: object): unknown },
  suffix: string
): UserNotificationsChannel {
  return socket.channel(`user:${suffix}`) as UserNotificationsChannel;
}

export function onUserNotificationsChannelMessage<E extends keyof UserNotificationsChannelEvents>(
  channel: UserNotificationsChannel,
  event: E,
  handler: (payload: UserNotificationsChannelEvents[E]) => void
): number {
  return channel.on(event, (payload: unknown) => handler(payload as UserNotificationsChannelEvents[E]));
}

export function onUserNotificationsChannelMessages(
  channel: UserNotificationsChannel,
  handlers: UserNotificationsChannelHandlers
): UserNotificationsChannelRefs {
  const refs: UserNotificationsChannelRefs = {};
  for (const event in handlers) {
    const e = event as keyof UserNotificationsChannelEvents;
    const handler = handlers[e];
    if (handler) {
      refs[e] = channel.on(event, (payload) => (handler as (p: unknown) => void)(payload));
    }
  }
  return refs;
}

export function unsubscribeUserNotificationsChannel(
  channel: UserNotificationsChannel,
  refs: UserNotificationsChannelRefs
): void {
  for (const event in refs) {
    const e = event as keyof UserNotificationsChannelRefs;
    const ref = refs[e];
    if (ref !== undefined) {
      channel.off(event, ref);
    }
  }
}