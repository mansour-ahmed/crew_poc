import { Link, Outlet, useParams } from "react-router-dom";
import { TopBar } from "../components/top-bar";
import { ConversationSidebar } from "../components/conversation-sidebar";

export function ChatLayout() {
  const { conversationId } = useParams<{ conversationId: string }>();
  const onConversationList = !conversationId;

  return (
    <div className="h-screen flex flex-col bg-base-100 text-base-content">
      <TopBar />
      <div className="flex flex-1 min-h-0">
        <aside
          className={`${onConversationList ? "flex" : "hidden lg:flex"} w-full lg:w-72 shrink-0 border-r border-base-content/10 flex-col`}
        >
          <div className="px-5 py-3 border-b border-base-content/10">
            <Link
              to="/"
              className="text-sm text-base-content/60 hover:text-base-content transition-colors inline-flex items-center gap-1.5"
            >
              ← Back to feed
            </Link>
          </div>
          <div className="flex-1 overflow-y-auto">
            <ConversationSidebar />
          </div>
        </aside>
        <section
          className={`${onConversationList ? "hidden lg:flex" : "flex"} flex-1 min-w-0 flex-col`}
        >
          <Outlet />
        </section>
      </div>
    </div>
  );
}
