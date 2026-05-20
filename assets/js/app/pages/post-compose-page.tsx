import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Link, useNavigate } from "react-router-dom";
import { usePostMutation } from "../hooks/use-post-mutation";
import { useCurrentUser } from "../contexts/current-user-context";
import { LOCALES } from "../lib/locales";

const LOCALE_VALUES = LOCALES.map((l) => l.value) as [string, ...string[]];

const schema = z.object({
  title: z.string().trim().min(1, "Title is required").max(200),
  body: z.string().trim().min(1, "Body is required"),
  originalLocale: z.enum(LOCALE_VALUES),
  requiresAcknowledgement: z.boolean(),
});

type FormValues = z.infer<typeof schema>;

export function PostComposePage() {
  const navigate = useNavigate();
  const { currentUser } = useCurrentUser();
  const mutation = usePostMutation();

  const defaultLocale = (currentUser?.locale ?? "en") as FormValues["originalLocale"];

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      title: "",
      body: "",
      originalLocale: defaultLocale,
      requiresAcknowledgement: false,
    },
  });

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

      <h1 className="text-2xl font-semibold tracking-tight">New post</h1>
      <p className="text-sm text-base-content/60 mt-1">
        Share an announcement with your team.
      </p>

      <form onSubmit={handleSubmit(onSubmit)} className="mt-8 space-y-5">
        <div>
          <label className="text-sm font-medium" htmlFor="post-title">
            Title
          </label>
          <input
            id="post-title"
            type="text"
            placeholder="What's it about?"
            className="input input-bordered w-full mt-1"
            {...register("title")}
          />
          {errors.title ? (
            <p className="text-xs text-error mt-1">{errors.title.message}</p>
          ) : null}
        </div>

        <div>
          <label className="text-sm font-medium" htmlFor="post-body">
            Body
          </label>
          <textarea
            id="post-body"
            rows={8}
            placeholder="Write the full announcement…"
            className="textarea textarea-bordered w-full mt-1 resize-y"
            {...register("body")}
          />
          {errors.body ? (
            <p className="text-xs text-error mt-1">{errors.body.message}</p>
          ) : null}
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
          <div>
            <label className="text-sm font-medium" htmlFor="post-locale">
              Language
            </label>
            <select
              id="post-locale"
              className="select select-bordered w-full mt-1"
              {...register("originalLocale")}
            >
              {LOCALES.map((opt) => (
                <option key={opt.value} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div className="space-y-2">
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              className="checkbox checkbox-sm"
              {...register("requiresAcknowledgement")}
            />
            <span className="text-sm">Require acknowledgement</span>
          </label>
        </div>

        {mutation.isError ? (
          <p className="text-sm text-error" role="alert">
            Couldn't publish — try again.
          </p>
        ) : null}

        <div className="flex items-center gap-3 pt-2">
          <button
            type="submit"
            disabled={isSubmitting || mutation.isPending}
            className="btn btn-primary"
          >
            {mutation.isPending ? "Publishing…" : "Publish"}
          </button>
          <Link to="/" className="btn btn-ghost">
            Cancel
          </Link>
        </div>
      </form>
    </div>
  );
}
