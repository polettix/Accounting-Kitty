use utf8;
package Accounting::Kitty::Result::QuotaFinance;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Accounting::Kitty::Result::QuotaFinance

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<quota_finance>

=cut

__PACKAGE__->table("quota_finance");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 group_id

  data_type: 'integer'
  is_nullable: 1

=head2 name

  data_type: 'text'
  is_nullable: 1

=head2 is_visible

  data_type: 'integer'
  is_nullable: 1

=head2 account_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 sequence_number

  data_type: 'integer'
  is_nullable: 1

=head2 weight

  data_type: 'integer'
  is_nullable: 1

=head2 is_active

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "group_id",
  { data_type => "integer", is_nullable => 1 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "is_visible",
  { data_type => "integer", is_nullable => 1 },
  "account_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "sequence_number",
  { data_type => "integer", is_nullable => 1 },
  "weight",
  { data_type => "integer", is_nullable => 1 },
  "is_active",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 account

Type: belongs_to

Related object: L<Accounting::Kitty::Result::Account>

=cut

__PACKAGE__->belongs_to(
  "account",
  "Accounting::Kitty::Result::Account",
  { id => "account_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2013-07-27 21:20:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7ZekhjoLkSMphvuKluPrZg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
