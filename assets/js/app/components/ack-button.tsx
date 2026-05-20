import { useAck } from "../hooks/use-ack";

interface AckButtonProps {
  postId: string;
  acknowledged: boolean;
}

export function AckButton({ postId, acknowledged }: AckButtonProps) {
  const ack = useAck();

  if (acknowledged) {
    return (
      <span className="inline-flex items-center gap-1.5 text-xs text-success font-medium animate-pop-in">
        <span aria-hidden="true">✓</span> Acknowledged
      </span>
    );
  }

  return (
    <button
      type="button"
      onClick={() => ack.mutate({ postId })}
      disabled={ack.isPending}
      className="btn btn-xs btn-primary transition-transform active:scale-95 disabled:active:scale-100"
    >
      Acknowledge
    </button>
  );
}
