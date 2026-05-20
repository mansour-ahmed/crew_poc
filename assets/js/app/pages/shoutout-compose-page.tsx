import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Link, useNavigate } from "react-router-dom";
import { useShoutoutMutation } from "../hooks/use-post-mutation";
import { useOrgUsers } from "../hooks/use-org-users";
import { useCurrentUser } from "../contexts/current-user-context";

const schema = z.object({
  recipientId: z.string().uuid("Pick someone"),
  body: z.string().trim().min(1, "Say something nice"),
});

type FormValues = z.infer<typeof schema>;

export function ShoutoutComposePage() {
  const navigate = useNavigate();
  const { currentUser } = useCurrentUser();
  const { data: users } = useOrgUsers();
  const mutation = useShoutoutMutation();

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { recipientId: "", body: "" },
  });

  // Can't shout out to yourself.
  const recipients = (users ?? []).filter((u) => u.id !== currentUser?.id);

  function onSubmit(values: FormValues) {
    mutation.mutate(values, {
      onSuccess: () => navigate("/"),
    });
  }

  return (
    <div className="max-w-2xl">
      <div className="mb-6">
        <Link to="/" className="text-sm text-base-content/60 hover:text-base-content">
          ← Back to feed
        </Link>
      </div>

      <h1 className="text-2xl font-semibold tracking-tight">Send a shoutout</h1>
      <p className="text-sm text-base-content/60 mt-1">
        Recognize a teammate for something they did well.
      </p>

      <form onSubmit={handleSubmit(onSubmit)} className="mt-8 space-y-5">
        <div>
          <label className="text-sm font-medium" htmlFor="shoutout-recipient">
            Recipient
          </label>
          <select
            id="shoutout-recipient"
            className="select select-bordered w-full mt-1"
            defaultValue=""
            {...register("recipientId")}
          >
            <option value="" disabled>
              Who deserves recognition?
            </option>
            {recipients.map((u) => (
              <option key={u.id} value={u.id}>
                {u.name}
              </option>
            ))}
          </select>
          {errors.recipientId ? (
            <p className="text-xs text-error mt-1">{errors.recipientId.message}</p>
          ) : null}
        </div>

        <div>
          <label className="text-sm font-medium" htmlFor="shoutout-body">
            Message
          </label>
          <textarea
            id="shoutout-body"
            rows={6}
            placeholder="What did they do that was great?"
            className="textarea textarea-bordered w-full mt-1 resize-y"
            {...register("body")}
          />
          {errors.body ? (
            <p className="text-xs text-error mt-1">{errors.body.message}</p>
          ) : null}
        </div>

        {mutation.isError ? (
          <p className="text-sm text-error" role="alert">
            Couldn't send — try again.
          </p>
        ) : null}

        <div className="flex items-center gap-3 pt-2">
          <button
            type="submit"
            disabled={isSubmitting || mutation.isPending}
            className="btn btn-secondary"
          >
            {mutation.isPending ? "Sending…" : "Send shoutout"}
          </button>
          <Link to="/" className="btn btn-ghost">
            Cancel
          </Link>
        </div>
      </form>
    </div>
  );
}
