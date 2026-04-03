defmodule Polar.Storage do
  @moduledoc """
  Storage backend abstraction for image artifacts.

  Configure the adapter in config/runtime.exs:

      config :polar, :storage_adapter, Polar.Storage.S3
      # or
      config :polar, :storage_adapter, Polar.Storage.Local
  """

  @type path :: String.t()
  @type opts :: keyword()

  @callback get_signed_url(path(), opts()) :: String.t()
  @callback put_object(path(), binary(), opts()) :: :ok | {:error, term()}
  @callback delete_object(path()) :: :ok | {:error, term()}

  def get_signed_url(path, opts \\ []), do: adapter().get_signed_url(path, opts)
  def put_object(path, data, opts \\ []), do: adapter().put_object(path, data, opts)
  def delete_object(path), do: adapter().delete_object(path)

  defp adapter do
    Application.get_env(:polar, :storage_adapter, Polar.Storage.S3)
  end
end
