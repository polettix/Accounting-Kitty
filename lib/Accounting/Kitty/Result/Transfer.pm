package Accounting::Kitty::Result::Transfer;

use utf8;
use strict;
use warnings;
use Carp;
{ our $VERSION = '0.001'; }

use base 'Accounting::Kitty::Result::TransferBase';
__PACKAGE__->table("transfer");

sub src {
   my $self = shift;
   return $self->{_invert} ? $self->SUPER::dst(@_) : $self->SUPER::src(@_);
} ## end sub src

sub dst {
   my $self = shift;
   return $self->{_invert} ? $self->SUPER::src(@_) : $self->SUPER::dst(@_);
} ## end sub dst

sub amount {
   my $self   = shift;
   my $invert = $self->{_invert};
   if (@_) {
      my $amount = shift;
      $self->SUPER::amount($invert ? -$amount : $amount);
   }
   my $amount = $self->SUPER::amount();
   return $invert ? -$amount : $amount;
}

sub discard_changes {
   my $self = shift;
   my $invert = $self->{_invert};
   $self->SUPER::discard_changes(@_);
   $self->{_invert} = $invert;
   return $self;
}

sub invert {
   my $self = shift;
   return $self->{_invert} = (@_ && (!$_[0])) ? 0 : 1;
}

sub is_inverted {
   return shift->{_invert};
}

sub invert_toggle {
   my $self = shift;
   return $self->invert(!$self->{_invert});
}

1;
