defmodule LangchainPrompt.Attachment do
  @moduledoc """
  A file attachment to be sent alongside a prompt to the LLM.

  Attachments are adapter-agnostic containers for binary data (images, PDFs,
  etc.) that get merged into the user message by `LangchainPrompt.execute/4`.

  ## Creating attachments

      # From raw base64 data
      %Attachment{type: :image, content: base64_data, media: :jpg}

      # From a file on disk (reads, base64-encodes, infers media type)
      Attachment.from_file!("/path/to/menu.jpg")

  ## Supported extensions

  | Extension        | `:type`  | `:media` |
  |------------------|----------|----------|
  | `.jpg` / `.jpeg` | `:image` | `:jpg`   |
  | `.png`           | `:image` | `:png`   |
  | `.gif`           | `:image` | `:gif`   |
  | `.webp`          | `:image` | `:webp`  |
  | `.pdf`           | `:file`  | `:pdf`   |
  """

  @enforce_keys [:type, :content, :media]
  defstruct [:type, :content, :media]

  @type t :: %__MODULE__{
          type: :image | :file,
          content: binary(),
          media: atom() | String.t()
        }

  @image_extensions %{
    ".jpg" => :jpg,
    ".jpeg" => :jpg,
    ".png" => :png,
    ".gif" => :gif,
    ".webp" => :webp
  }

  @file_extensions %{
    ".pdf" => :pdf
  }

  @doc """
  Creates an `Attachment` from a file path.

  Reads the file, base64-encodes the content, and infers the `:type` and
  `:media` from the file extension.

  Raises `ArgumentError` on unsupported extensions and re-raises any
  `File.Error` from reading the file.
  """
  @spec from_file!(path :: String.t()) :: t() | no_return()
  def from_file!(path) do
    ext = path |> Path.extname() |> String.downcase()
    {type, media} = resolve_type!(ext)
    content = path |> File.read!() |> Base.encode64()

    %__MODULE__{type: type, content: content, media: media}
  end

  defp resolve_type!(ext) do
    cond do
      media = Map.get(@image_extensions, ext) -> {:image, media}
      media = Map.get(@file_extensions, ext) -> {:file, media}
      true -> raise ArgumentError, "unsupported file extension: #{ext}"
    end
  end
end
