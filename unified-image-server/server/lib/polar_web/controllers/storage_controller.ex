defmodule PolarWeb.StorageController do
  @moduledoc """
  Serves locally-stored artifacts when using Polar.Storage.Local.
  Validates the HMAC token issued by get_signed_url/2 before streaming.
  Not used when the S3 adapter is active.
  """

  use PolarWeb, :controller

  alias Polar.Storage.Local

  def show(conn, %{"path" => parts, "token" => token, "expires" => expires_str}) do
    object_path = Path.join(parts)
    expires_at  = String.to_integer(expires_str)

    with :ok       <- Local.verify_token(object_path, token, expires_at),
         full_path <- Local.full_path(object_path),
         true      <- File.exists?(full_path) do
      conn
      |> put_resp_content_type(MIME.from_path(full_path))
      |> send_file(200, full_path)
    else
      {:error, :invalid_token} ->
        conn |> put_status(403) |> json(%{error: "invalid or expired token"})
      false ->
        conn |> put_status(404) |> json(%{error: "not found"})
    end
  end

  def show(conn, _params) do
    conn |> put_status(400) |> json(%{error: "missing token or expires"})
  end
end
