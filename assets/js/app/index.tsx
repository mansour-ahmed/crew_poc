import React from "react";
import { createRoot } from "react-dom/client";

function App() {
  return (
    <div className="min-h-screen bg-base-100 text-base-content flex items-center justify-center">
      <div className="text-center">
        <h1 className="text-3xl font-bold mb-2">CrewPoc</h1>
        <p className="opacity-70">SPA is mounted.</p>
      </div>
    </div>
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
