import React from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { CurrentUserProvider } from "./contexts/current-user-context";
import { SocketProvider } from "./contexts/socket-context";
import { ToastProvider } from "./contexts/toast-context";
import { AppLayout } from "./layouts/app-layout";
import { ChatLayout } from "./layouts/chat-layout";
import { FeedPage } from "./pages/feed-page";
import { PostComposePage } from "./pages/post-compose-page";
import { ShoutoutComposePage } from "./pages/shoutout-compose-page";
import { ConversationView, ChatIndex } from "./pages/conversation-view";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      retry: 1,
    },
  },
});

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <CurrentUserProvider>
          <SocketProvider>
            <ToastProvider>
              <Routes>
                <Route element={<AppLayout />}>
                  <Route index element={<FeedPage />} />
                  <Route path="/posts/new" element={<PostComposePage />} />
                  <Route path="/shoutouts/new" element={<ShoutoutComposePage />} />
                </Route>
                <Route path="/chat" element={<ChatLayout />}>
                  <Route index element={<ChatIndex />} />
                  <Route path=":conversationId" element={<ConversationView />} />
                </Route>
              </Routes>
            </ToastProvider>
          </SocketProvider>
        </CurrentUserProvider>
      </BrowserRouter>
    </QueryClientProvider>
  );
}

const root = document.getElementById("app");
if (root) {
  createRoot(root).render(
    <React.StrictMode>
      <App />
    </React.StrictMode>,
  );
}
