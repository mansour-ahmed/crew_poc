
interface Props {
  name: string;
  id: string;
  size?: "sm" | "md" | "lg";
}

function hashId(id: string): number {
  let hash = 0;
  for (let i = 0; i < id.length; i++) {
    hash = (hash * 31 + id.charCodeAt(i)) & 0xfffffff;
  }
  return hash;
}

function initials(name: string): string {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((word) => word[0].toUpperCase())
    .join("");
}

const sizeClasses: Record<NonNullable<Props["size"]>, string> = {
  sm: "w-7 h-7 text-[11px]",
  md: "w-9 h-9 text-sm",
  lg: "w-12 h-12 text-lg",
};

export function UserAvatar({ name, id, size = "md" }: Props) {
  const hue = hashId(id) % 360;
  const color = `hsl(${hue}, 65%, 55%)`;

  return (
    <div
      className={`${sizeClasses[size]} rounded-full flex items-center justify-center font-semibold text-white flex-shrink-0 transition-transform duration-150 hover:scale-105 shadow-sm`}
      style={{ backgroundColor: color }}
      title={name}
    >
      <span className="leading-none tracking-tight">{initials(name)}</span>
    </div>
  );
}
