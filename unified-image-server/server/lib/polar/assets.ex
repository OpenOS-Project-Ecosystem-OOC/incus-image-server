defmodule Polar.Assets do
  @moduledoc """
  Backward-compatibility shim. Delegates to Polar.Storage.S3.

  Existing callers of Polar.Assets.get_signed_url/2 and Polar.Assets.config/0
  continue to work. New code should call Polar.Storage directly.
  """

  defdelegate get_signed_url(object_path, opts \\ []), to: Polar.Storage.S3
  defdelegate config(), to: Polar.Storage.S3

  def client(access_key_id, secret_access_key, region, options \\ []) do
    finch_name = Keyword.get(options, :finch, Polar.Finch)

    access_key_id
    |> AWS.Client.create(secret_access_key, region)
    |> AWS.Client.put_http_client({AWS.HTTPClient.Finch, [finch_name: finch_name]})
  end
end
