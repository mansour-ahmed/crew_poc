// Thin wrappers over Phoenix Channel that use the codegen's event payload
// types but skip its branded channel shells (which hide join/leave). Each
// export is a {create, on} pair tied to one channel's event map.

import type { Channel, Socket } from "phoenix";
import type {
  ChatConversationChannelEvents,
  OrgFeedChannelEvents,
  UserNotificationsChannelEvents,
} from "../../ash_types";

function defineChannel<Events>(topicFor: (suffix: string) => string) {
  return {
    create(socket: Socket, suffix: string): Channel {
      return socket.channel(topicFor(suffix));
    },
    on<E extends keyof Events & string>(
      channel: Channel,
      event: E,
      handler: (payload: Events[E]) => void,
    ): number {
      return channel.on(event, (payload: unknown) => handler(payload as Events[E]));
    },
  };
}

export const ChatConversation = defineChannel<ChatConversationChannelEvents>(
  (suffix) => `chat:conversation:${suffix}`,
);

export const UserNotifications = defineChannel<UserNotificationsChannelEvents>(
  (suffix) => `user:${suffix}`,
);

export const OrgFeed = defineChannel<OrgFeedChannelEvents>(
  (suffix) => `org:${suffix}`,
);
