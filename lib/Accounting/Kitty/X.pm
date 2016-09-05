package Accounting::Kitty::X;

use utf8;
use strict;
use warnings;
use 5.010;
{ our $VERSION = '0.001'; }

use overload (q<""> => 'expanded_message');

use Moo;
use Scalar::Util qw< blessed >;
use Template::Perlish qw< render >;

has title => (
   is => 'ro',
   default => 'Bad Request',
);

has code => (
   is => 'ro',
   default => 400,
);

has id => (
   is => 'ro',
   default => undef,
);

has message => (
   is => 'rw',
   default => 'canned_message',
);

has expanded_message => (
   is => 'ro',
   lazy => 1,
   builder => '_BUILD_expanded_message',
);

has vars => (
   is => 'ro',
   default => sub { return {} },
);

sub _BUILD_expanded_message {
   my $self = shift;
   return render($self->message(), $self->vars());
}

sub throw {
   my $self = shift;
   $self = $self->new(@_) unless blessed($self);
   die $self;
}

sub caught {
   my ($self, $x) = @_;
   return blessed($x) && $x->isa(ref($self) || $self);
}

sub canned_message {
   my $self = shift;
   my $id = shift // $self->id() // 1;
   state $message_for = {
      1 => 'Something was wrong with your request',
   };
   $id = 1 unless exists $message_for->{$id};
   return $message_for->{$id};
}

1;
