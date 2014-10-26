
package metaclass;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed';

our $VERSION   = '0.04';
our $AUTHORITY = 'cpan:STEVAN';

use Class::MOP;

sub import {
    shift;
    my $metaclass;
    if (!defined($_[0]) || $_[0] =~ /^(attribute|method|instance)_metaclass/) {
        $metaclass = 'Class::MOP::Class';
    }
    else {
        $metaclass = shift;
        #make sure the custom metaclass gets loaded
        Class::MOP::load_class($metaclass);
        ($metaclass->isa('Class::MOP::Class'))
            || confess "The metaclass ($metaclass) must be derived from Class::MOP::Class";
    }
    my %options = @_;
    #make sure the custom metaclasses get loaded
    map{ Class::MOP::load_class($options{$_}) }
      grep{ /^(attribute|method|instance)_metaclass/ } keys %options;
    my $package = caller();

    # create a meta object so we can install &meta
    my $meta = $metaclass->initialize($package => %options);
    $meta->add_method('meta' => sub {
        # we must re-initialize so that it
        # works as expected in subclasses,
        # since metaclass instances are
        # singletons, this is not really a
        # big deal anyway.
        $metaclass->initialize((blessed($_[0]) || $_[0]) => %options)
    });
}

1;

__END__

=pod

=head1 NAME

metaclass - a pragma for installing and using Class::MOP metaclasses

=head1 SYNOPSIS

  package MyClass;

  # use Class::MOP::Class
  use metaclass;

  # ... or use a custom metaclass
  use metaclass 'MyMetaClass';

  # ... or use a custom metaclass
  # and custom attribute and method
  # metaclasses
  use metaclass 'MyMetaClass' => (
      'attribute_metaclass' => 'MyAttributeMetaClass',
      'method_metaclass'    => 'MyMethodMetaClass',
  );

  # ... or just specify custom attribute
  # and method classes, and Class::MOP::Class
  # is the assumed metaclass
  use metaclass (
      'attribute_metaclass' => 'MyAttributeMetaClass',
      'method_metaclass'    => 'MyMethodMetaClass',
  );

=head1 DESCRIPTION

This is a pragma to make it easier to use a specific metaclass
and a set of custom attribute and method metaclasses. It also
installs a C<meta> method to your class as well.

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2007 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
