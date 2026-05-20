import React from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { CurrentUserProvider } from "./contexts/current-user-context";
import { AppLayout } from "./layouts/app-layout";
import { FeedPage } from "./pages/feed-page";

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
          <Routes>
            <Route element={<AppLayout />}>
              <Route index element={<FeedPage />} />
            </Route>
          </Routes>
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
