defmodule Polar.Streams.Product do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias Polar.Streams.Version

  @valid_attrs ~w(aliases arch os release release_title requirements variant)a
  @required_attrs ~w(arch os release release_title variant)a

  schema "products" do
    field :aliases, :string
    field :arch, :string
    field :os, :string
    field :release, :string
    field :release_title, :string
    field :requirements, :string
    field :variant, :string

    has_many :versions, Version

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, @valid_attrs)
    |> validate_required(@required_attrs)
    # arch accepts any lowercase alphanumeric identifier — no fixed list.
    # Supports amd64, arm64, i386, riscv64, s390x, ppc64le, etc.
    |> validate_format(:arch, ~r/^[a-z0-9_]+$/,
      message: "must be a lowercase alphanumeric architecture identifier"
    )
    |> unique_constraint([:os, :release, :arch, :variant])
  end

  def by_key(query \\ __MODULE__, key) do
    from p in query,
      where: p.aliases == ^key or p.os == ^key
  end
end
