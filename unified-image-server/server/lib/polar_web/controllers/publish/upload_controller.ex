defmodule PolarWeb.Publish.UploadController do
  @moduledoc """
  Direct multipart upload endpoint — alternative to the icepak CI/CD flow.

  POST /publish/products/:product_id/versions/:version_id/upload

  Accepts multipart fields: rootfs, metadata, kvmdisk.
  Files are streamed in chunks; SHA-256 is computed incrementally.
  Never loads the full file into memory — safe for multi-GB rootfs files.
  """

  use PolarWeb, :controller

  alias Polar.Repo
  alias Polar.Streams
  alias Polar.Streams.Product
  alias Polar.Streams.Version
  alias Polar.Storage

  action_fallback PolarWeb.FallbackController

  @chunk_size 4 * 1024 * 1024       # 4 MB read chunks
  @max_file_size 4 * 1024 * 1024 * 1024  # 4 GB limit

  def create(%{assigns: %{current_space: _space}} = conn,
             %{"product_id" => product_id, "version_id" => version_id} = params) do
    with {:ok, product} <- fetch_product(product_id),
         {:ok, version} <- fetch_version(version_id, product),
         {:ok, items}   <- process_uploads(product, version, params) do
      conn |> put_status(:created) |> render(:create, %{items: items})
    end
  end

  defp fetch_product(id) do
    case Repo.get(Product, id) do
      nil     -> {:error, :not_found}
      product -> {:ok, product}
    end
  end

  defp fetch_version(id, product) do
    case Repo.get_by(Version, id: id, product_id: product.id) do
      nil     -> {:error, :not_found}
      version -> {:ok, version}
    end
  end

  defp process_uploads(product, version, params) do
    results =
      ~w(rootfs metadata kvmdisk)
      |> Enum.flat_map(fn field ->
        case Map.get(params, field) do
          %Plug.Upload{} = u -> [{field, u}]
          _                  -> []
        end
      end)
      |> Enum.map(fn {field, upload} -> store_upload(field, upload, product, version) end)

    case Enum.filter(results, &match?({:error, _}, &1)) do
      []     -> {:ok, Enum.map(results, fn {:ok, item} -> item end)}
      errors -> {:error, errors}
    end
  end

  defp store_upload(field, %Plug.Upload{path: tmp_path, filename: filename}, product, version) do
    storage_path = build_storage_path(product, version, filename)

    with :ok            <- validate_file_size(tmp_path),
         {:ok, hash, sz} <- stream_to_storage(tmp_path, storage_path),
         {:ok, item}    <- create_item(field, filename, hash, sz, storage_path, version) do
      {:ok, item}
    end
  end

  defp validate_file_size(path) do
    case File.stat(path) do
      {:ok, %{size: s}} when s <= @max_file_size -> :ok
      {:ok, %{size: s}} -> {:error, "file too large: #{fmt(s)} (max #{fmt(@max_file_size)})"}
      {:error, r}       -> {:error, r}
    end
  end

  # Stream file in @chunk_size chunks, hash incrementally, write to storage.
  defp stream_to_storage(tmp_path, storage_path) do
    {ctx, size, chunks} =
      tmp_path
      |> File.stream!([], @chunk_size)
      |> Enum.reduce({:crypto.hash_init(:sha256), 0, []}, fn chunk, {ctx, sz, acc} ->
        {:crypto.hash_update(ctx, chunk), sz + byte_size(chunk), [chunk | acc]}
      end)

    hash = ctx |> :crypto.hash_final() |> Base.encode16(case: :lower)
    data = chunks |> Enum.reverse() |> IO.iodata_to_binary()

    case Storage.put_object(storage_path, data) do
      :ok             -> {:ok, hash, size}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_storage_path(product, version, filename) do
    Path.join([product.os, product.release, product.arch,
               product.variant, version.serial, filename])
  end

  defp create_item(field, filename, hash, size, path, version) do
    Streams.create_item(version, %{
      name:        filename,
      file_type:   file_type_for(field, filename),
      hash:        hash,
      size:        size,
      path:        path,
      is_metadata: field == "metadata"
    })
  end

  defp file_type_for("metadata", _), do: "incus.tar.xz"
  defp file_type_for(_, filename) do
    cond do
      String.ends_with?(filename, ".tar.xz")  -> "tar.xz"
      String.ends_with?(filename, ".squashfs") -> "squashfs"
      true -> filename |> Path.extname() |> String.trim_leading(".")
    end
  end

  defp fmt(b) when b >= 1_073_741_824, do: "#{Float.round(b / 1_073_741_824, 1)} GB"
  defp fmt(b) when b >= 1_048_576,     do: "#{Float.round(b / 1_048_576, 1)} MB"
  defp fmt(b),                          do: "#{b} B"
end
