defmodule CrewPoc.Feed.TranslatedPost do
  @moduledoc """
  Return shape for the prompt-backed `PostTranslation.translate` action. The
  field declarations also drive the JSON schema given to the LLM for
  structured output.
  """

  use Ash.TypedStruct

  typed_struct do
    field :title, :string, allow_nil?: false
    field :body, :string, allow_nil?: false
  end
end
