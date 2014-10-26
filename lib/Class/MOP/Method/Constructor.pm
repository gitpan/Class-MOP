
package Class::MOP::Method::Constructor;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed', 'weaken', 'looks_like_number';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Method';

sub new {
    my $class   = shift;
    my %options = @_;
        
    (exists $options{options} && ref $options{options} eq 'HASH')
        || confess "You must pass a hash of options"; 
    
    my $self = bless {
        # from our superclass
        '&!body'          => undef,
        # specific to this subclass
        '%!options'       => $options{options},
        '$!meta_instance' => $options{metaclass}->get_meta_instance,
        '@!attributes'    => [ $options{metaclass}->compute_all_applicable_attributes ], 
        # ...
        '$!associated_metaclass' => $options{metaclass},
    } => $class;

    # we don't want this creating 
    # a cycle in the code, if not 
    # needed
    weaken($self->{'$!associated_metaclass'});    

    $self->intialize_body;

    return $self;    
}

## predicates

# NOTE:
# if it is blessed into this class, 
# then it is always inlined, that is 
# pretty much what this class is for.
sub is_inline { 1 }

## accessors 

sub options       { (shift)->{'%!options'}       }
sub meta_instance { (shift)->{'$!meta_instance'} }
sub attributes    { (shift)->{'@!attributes'}    }

sub associated_metaclass { (shift)->{'$!associated_metaclass'} }

## method

sub intialize_body {
    my $self = shift;
    # TODO:
    # the %options should also include a both 
    # a call 'initializer' and call 'SUPER::' 
    # options, which should cover approx 90% 
    # of the possible use cases (even if it 
    # requires some adaption on the part of 
    # the author, after all, nothing is free)
    my $source = 'sub {';
    $source .= "\n" . 'my ($class, %params) = @_;';
    $source .= "\n" . 'my $instance = ' . $self->meta_instance->inline_create_instance('$class');
    $source .= ";\n" . (join ";\n" => map { 
        $self->_generate_slot_initializer($_) 
    } 0 .. (@{$self->attributes} - 1));
    $source .= ";\n" . 'return $instance';
    $source .= ";\n" . '}'; 
    warn $source if $self->options->{debug};   
    
    my $code;
    {
        # NOTE:
        # create the nessecary lexicals
        # to be picked up in the eval 
        my $attrs = $self->attributes;
        
        $code = eval $source;
        confess "Could not eval the constructor :\n\n$source\n\nbecause :\n\n$@" if $@;
    }
    $self->{'&!body'} = $code;
}

sub _generate_slot_initializer {
    my $self  = shift;
    my $index = shift;
    
    my $attr = $self->attributes->[$index];
    
    my $default;
    if ($attr->has_default) {
        # NOTE:
        # default values can either be CODE refs
        # in which case we need to call them. Or 
        # they can be scalars (strings/numbers)
        # in which case we can just deal with them
        # in the code we eval.
        if ($attr->is_default_a_coderef) {
            $default = '$attrs->[' . $index . ']->default($instance)';
        }
        else {
            $default = $attr->default;
            # make sure to quote strings ...
            unless (looks_like_number($default)) {
                $default = "'$default'";
            }
        }
    }
    $self->meta_instance->inline_set_slot_value(
        '$instance', 
        ("'" . $attr->name . "'"), 
        ('$params{\'' . $attr->init_arg . '\'}' . (defined $default ? (' || ' . $default) : ''))
    );   
}

1;

1;

__END__

=pod

=head1 NAME 

Class::MOP::Method::Constructor - Method Meta Object for constructors

=head1 SYNOPSIS

  use Class::MOP::Method::Constructor;
  
  my $constructor = Class::MOP::Method::Constructor->new(
      metaclass => $metaclass,       
      options   => {
          debug => 1, # this is all for now
      },                        
  );
  
  # calling the constructor ...
  $constructor->body->($metaclass->name, %params);
  
=head1 DESCRIPTION

This is a subclass of C<Class::MOP::Method> which deals with 
class constructors.  

=head1 METHODS

=over 4

=item B<new (metaclass => $meta, options => \%options)>

=item B<options>

This returns the options HASH which is passed into C<new>.

=item B<associated_metaclass>

This returns the metaclass which is passed into C<new>.

=item B<attributes>

This returns the list of attributes which are associated with the 
metaclass which is passed into C<new>.

=item B<meta_instance>

This returns the meta instance which is associated with the 
metaclass which is passed into C<new>.

=item B<is_inline>

This returns a boolean, but since constructors are very rarely 
not inlined, this always returns true for now.

=item B<intialize_body>

This creates the code reference for the constructor itself. 

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2007 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

