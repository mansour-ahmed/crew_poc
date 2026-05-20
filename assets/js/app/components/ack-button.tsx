import { useAck } from "../hooks/use-ack";

interface AckButtonProps {
  postId: string;
  acknowledged: boolean;
}

export function AckButton({ postId, acknowledged }: AckButtonProps) {
  const ack = useAck();

  if (acknowledged) {
    return (
      <span className="inline-flex items-center gap-1.5 text-xs text-success font-medium">
        <span aria-hidden="true">✓</span> Acknowledged
      </span>
    );
  }

  return (
    <button
      type="button"
      onClick={() => ack.mutate({ postId })}
      disabled={ack.isPending}
      className="btn btn-xs btn-primary"
    >
      Acknowledge
    </button>
  );
}
