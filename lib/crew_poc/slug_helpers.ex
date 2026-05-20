defmodule CrewPoc.SlugHelpers do
  @moduledoc "Shared slug utilities for Ash resources."

  @doc "Returns a changeset with an auto-generated slug if one is not already set."
  @spec maybe_set_slug(Ash.Changeset.t()) :: Ash.Changeset.t()
  def maybe_set_slug(changeset) do
    if Ash.Changeset.get_attribute(changeset, :slug) do
      changeset
    else
      name = Ash.Changeset.get_attribute(changeset, :name) || ""
      slug = slugify(name)
      Ash.Changeset.change_attribute(changeset, :slug, slug)
    end
  end

  @spec slugify(String.t()) :: String.t()
  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end
end
