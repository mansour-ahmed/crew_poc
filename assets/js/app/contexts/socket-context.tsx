import React, { createContext, useContext, useEffect, useState } from "react";
import { Socket } from "phoenix";
import { useCurrentUser } from "./current-user-context";

const SocketContext = createContext<Socket | null>(null);

export function SocketProvider({ children }: { children: React.ReactNode }) {
  const { currentUser } = useCurrentUser();
  const [socket, setSocket] = useState<Socket | null>(null);

  useEffect(() => {
    if (!currentUser) {
      setSocket(null);
      return;
    }

    const next = new Socket("/socket", {
      params: { user_id: currentUser.id },
    });

    next.connect();
    setSocket(next);

    return () => {
      next.disconnect();
      setSocket(null);
    };
  }, [currentUser?.id]);

  return <SocketContext.Provider value={socket}>{children}</SocketContext.Provider>;
}

export const useSocket = () => useContext(SocketContext);
