package Accounting::Kitty::Result::Account;

use utf8;
use strict;
use warnings;
{ our $VERSION = '0.001'; }

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime');

__PACKAGE__->table('account');

__PACKAGE__->add_columns(
   id => {
      data_type         => 'integer',
      is_auto_increment => 1,
      is_nullable       => 0
   },
   owner_id => {
      data_type      => 'integer',
      is_foreign_key => 1,
      is_nullable    => 1,
   },
   project_id => {
      data_type      => 'integer',
      is_foreign_key => 1,
      is_nullable    => 1,
   },
   name  => {data_type => 'text',    is_nullable => 1},
   data  => {data_type => 'text',    is_nullable => 1},
   total => {data_type => 'integer', is_nullable => 1},
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(
   owner => 'Accounting::Kitty::Result::Owner',
   {id => 'owner_id'},
   {
      is_deferrable => 1,
      join_type     => 'LEFT',
      on_delete     => 'CASCADE',
      on_update     => 'CASCADE',
   },
);

__PACKAGE__->belongs_to(
   project => 'Accounting::Kitty::Result::Project',
   {id => 'project_id'},
   {
      is_deferrable => 1,
      join_type     => 'LEFT',
      on_delete     => 'CASCADE',
      on_update     => 'CASCADE',
   },
);

__PACKAGE__->has_many(
   quota_finances => 'Accounting::Kitty::Result::QuotaFinance',
   {'foreign.account_id' => 'self.id'},
   {cascade_copy         => 0, cascade_delete => 0},
);

__PACKAGE__->has_many(
   quotas => 'Accounting::Kitty::Result::Quota',
   {'foreign.account_id' => 'self.id'},
   {cascade_copy         => 0, cascade_delete => 0},
);

__PACKAGE__->has_many(
   transfer_dsts => 'Accounting::Kitty::Result::Transfer',
   {'foreign.dst_id' => 'self.id'},
   {cascade_copy  => 0, cascade_delete => 0},
);

__PACKAGE__->has_many(
   transfer_srcs => 'Accounting::Kitty::Result::Transfer',
   {'foreign.src_id' => 'self.id'},
   {cascade_copy  => 0, cascade_delete => 0},
);

sub add_amount {
   my ($self, $amount) = @_;
   $self->total($self->total() + $amount);
   $self->update();
   if (my $owner = $self->owner()) {
      $self->owner()->_add($amount);
   }
   return $self;
} ## end sub add_amount

sub as_hash {
   my $self = shift;
   my %retval = $self->get_columns();
   return %retval if wantarray();
   return \%retval;
} ## end sub as_hash

sub quotas_any {
   my $self = shift;
   my @retval = ($self->quotas(), $self->quota_finances());
   return @retval if wantarray();
   return \@retval;
}

sub subtract_amount {
   my ($self, $amount) = @_;
   $self->total($self->total() - $amount);
   $self->update();
   if (my $owner = $self->owner()) {
      $self->owner()->_add(-$amount);
   }
   return $self;
} ## end sub subtract_amount

sub transfers {
   my ($self, $count) = @_;
   my @query = ({}, {});
   if ($count) {
      $query[1] = {
         rows     => $count,
         order_by => {-desc => 'date_'},
      };
   } ## end if ($count)
   my @retval = reverse sort {
           ($a->get_column('date_') cmp $b->get_column('date_'))
        || ($a->get_column('id') <=> $b->get_column('id'))
   } ($self->transfer_dsts(@query), $self->transfer_srcs(@query));
   splice @retval, $count if $count && @retval >= $count;
   return @retval if wantarray();
   return \@retval;
} ## end sub transfers

sub transfers_active {
   my $self = shift;
   return [grep { !$_->deleted() } @{$self->transfers(@_)}];
}

sub TO_JSON { return scalar(shift->as_hash()) }

1;
