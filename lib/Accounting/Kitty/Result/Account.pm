use utf8;

package Accounting::Kitty::Result::Account;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Accounting::Kitty::Result::Account

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

=head1 TABLE: C<account>

=cut

__PACKAGE__->table("account");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 1

=head2 type

  data_type: 'text'
  is_nullable: 1

=head2 total

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
   "id",
   {data_type => "integer", is_auto_increment => 1, is_nullable => 0},
   "name",
   {data_type => "text", is_nullable => 1},
   "_type",
   {data_type => "text", is_nullable => 1, accessor => 'type'},
   "total",
   {data_type => "integer", is_nullable => 1},
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 quota_finances

Type: has_many

Related object: L<Accounting::Kitty::Result::QuotaFinance>

=cut

__PACKAGE__->has_many(
   "quota_finances",
   "Accounting::Kitty::Result::QuotaFinance",
   {"foreign.account_id" => "self.id"},
   {cascade_copy         => 0, cascade_delete => 0},
);

=head2 quotas

Type: has_many

Related object: L<Accounting::Kitty::Result::Quota>

=cut

__PACKAGE__->has_many(
   "quotas",
   "Accounting::Kitty::Result::Quota",
   {"foreign.account_id" => "self.id"},
   {cascade_copy         => 0, cascade_delete => 0},
);

=head2 transfer_dsts

Type: has_many

Related object: L<Accounting::Kitty::Result::Transfer>

=cut

__PACKAGE__->has_many(
   "transfer_dsts",
   "Accounting::Kitty::Result::Transfer",
   {"foreign.dst" => "self.id"},
   {cascade_copy  => 0, cascade_delete => 0},
);

=head2 transfer_srcs

Type: has_many

Related object: L<Accounting::Kitty::Result::Transfer>

=cut

__PACKAGE__->has_many(
   "transfer_srcs",
   "Accounting::Kitty::Result::Transfer",
   {"foreign.src" => "self.id"},
   {cascade_copy  => 0, cascade_delete => 0},
);

# Created by DBIx::Class::Schema::Loader v0.07022 @ 2013-07-27 14:31:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/O0Wco2uWyuXA0q8/lGm4A

use Accounting::Kitty::TransferProxy;

sub add_amount {
   my ($self, $amount) = @_;
   $self->total($self->total() + $amount);
   $self->update();
   return $self;
} ## end sub add_amount

sub subtract_amount {
   my ($self, $amount) = @_;
   $self->total($self->total() - $amount);
   $self->update();
   return $self;
} ## end sub subtract_amount

sub transfers {
   my ($self, $count) = @_;
   my @query = ({}, {});
   if ($count) {
      $query[1] = {
         rows     => $count,
         order_by => {-desc => 'tdate'},
      };
   } ## end if ($count)
   my $class  = 'Accounting::Kitty::TransferProxy';
   my @retval = reverse sort {
           ($a->get_column('tdate') cmp $b->get_column('tdate'))
        || ($a->get_column('id') <=> $b->get_column('id'))
     } (
      # destination transfers are accounted as "straight"
      (
         map { $class->new(transfer => $_, invert => 0) }
           $self->transfer_dsts(@query)
      ),

      # source transfers are accounted as "inverted"
      (
         map { $class->new(transfer => $_, invert => 1) }
           $self->transfer_srcs(@query)
      )
     );
   splice @retval, $count if $count && @retval >= $count;
   return \@retval;
} ## end sub transfers

sub active_transfers {
   my $self = shift;
   return [grep { !$_->deleted() } @{$self->transfers(@_)}];
}

sub TO_JSON {
   my $self = shift;
   return {
      name  => $self->name(),
      type  => $self->type(),
      total => $self->total(),
   };
} ## end sub TO_JSON

1;
