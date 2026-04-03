defmodule Polar.Repo.Migrations.RemoveArchAllowlistConstraint do
  use Ecto.Migration

  @doc """
  The arch column on products has always been a free-form :citext column with
  no database-level CHECK constraint. The only restriction was a
  validate_inclusion/3 in the Polar.Streams.Product changeset limiting values
  to ["amd64", "arm64"].

  That changeset constraint has been replaced with validate_format/4 accepting
  any lowercase alphanumeric string, enabling amd64, arm64, i386, riscv64,
  s390x, ppc64le, etc. without code changes.

  This migration is a no-op at the database level — it exists to document the
  change in the migration history and to serve as a rollback marker.
  """

  def up do
    # No database change required. The arch column is already unconstrained.
    # Existing rows with arch values outside the old allowlist are unaffected.
    :ok
  end

  def down do
    # Cannot restore the changeset-only constraint via a migration.
    # To re-restrict arch values, update the changeset in
    # lib/polar/streams/product.ex.
    :ok
  end
end
