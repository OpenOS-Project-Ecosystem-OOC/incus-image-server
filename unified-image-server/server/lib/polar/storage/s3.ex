defmodule Polar.Storage.S3 do
  @moduledoc """
  S3-compatible storage adapter (AWS S3, MinIO, Cloudflare R2, Backblaze B2).

  Configuration:

      config :polar, Polar.Storage.S3,
        access_key_id:     System.get_env("STORAGE_ACCESS_KEY_ID"),
        secret_access_key: System.get_env("STORAGE_SECRET_ACCESS_KEY"),
        region:            System.get_env("STORAGE_REGION", "us-east-1"),
        bucket:            System.get_env("STORAGE_BUCKET"),
        endpoint:          System.get_env("STORAGE_ENDPOINT")
        # endpoint: nil for AWS S3; URL string for MinIO/R2/B2
  """

  @behaviour Polar.Storage

  @impl true
  def get_signed_url(object_path, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, 3600)
    body_digest = Keyword.get(opts, :body_digest, "UNSIGNED-PAYLOAD")

    %{access_key_id: aki, secret_access_key: sak, region: region} = config()

    :aws_signature.sign_v4_query_params(
      aki, sak, region, "s3",
      :erlang.universaltime(),
      "GET",
      build_url(object_path),
      ttl: ttl, body_digest: body_digest
    )
  end

  @impl true
  def put_object(object_path, data, opts \\ []) do
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")
    %{bucket: bucket} = config()

    case AWS.S3.put_object(client(), bucket, object_path, %{
           "Body" => data,
           "ContentType" => content_type
         }) do
      {:ok, _, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete_object(object_path) do
    %{bucket: bucket} = config()

    case AWS.S3.delete_object(client(), bucket, object_path, %{}) do
      {:ok, _, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def config do
    Application.get_env(:polar, __MODULE__, [])
    |> Enum.into(%{endpoint: nil})
  end

  defp client do
    %{access_key_id: aki, secret_access_key: sak, region: region} = config()

    aki
    |> AWS.Client.create(sak, region)
    |> AWS.Client.put_http_client({AWS.HTTPClient.Finch, [finch_name: Polar.Finch]})
  end

  defp build_url(object_path) do
    %{endpoint: endpoint, bucket: bucket} = config()

    if endpoint do
      Path.join(["https://", endpoint, bucket, object_path])
    else
      "https://#{bucket}.s3.amazonaws.com/#{object_path}"
    end
  end
end
