
package Class::MOP::Method::Wrapped;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'reftype', 'blessed';
use Sub::Name    'subname';

our $VERSION   = '0.02';
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Method';	

# NOTE:
# this ugly beast is the result of trying 
# to micro optimize this as much as possible
# while not completely loosing maintainability.
# At this point it's "fast enough", after all
# you can't get something for nothing :)
my $_build_wrapped_method = sub {
	my $modifier_table = shift;
	my ($before, $after, $around) = (
		$modifier_table->{before},
		$modifier_table->{after},		
		$modifier_table->{around},		
	);
	if (@$before && @$after) {
		$modifier_table->{cache} = sub {
			$_->(@_) for @{$before};
			my @rval;
			((defined wantarray) ?
				((wantarray) ? 
					(@rval = $around->{cache}->(@_)) 
					: 
					($rval[0] = $around->{cache}->(@_)))
				:
				$around->{cache}->(@_));
			$_->(@_) for @{$after};			
			return unless defined wantarray;
			return wantarray ? @rval : $rval[0];
		}		
	}
	elsif (@$before && !@$after) {
		$modifier_table->{cache} = sub {
			$_->(@_) for @{$before};
			return $around->{cache}->(@_);
		}		
	}
	elsif (@$after && !@$before) {
		$modifier_table->{cache} = sub {
			my @rval;
			((defined wantarray) ?
				((wantarray) ? 
					(@rval = $around->{cache}->(@_)) 
					: 
					($rval[0] = $around->{cache}->(@_)))
				:
				$around->{cache}->(@_));
			$_->(@_) for @{$after};			
			return unless defined wantarray;
			return wantarray ? @rval : $rval[0];
		}		
	}
	else {
		$modifier_table->{cache} = $around->{cache};
	}
};

sub wrap {
	my $class = shift;
	my $code  = shift;
	(blessed($code) && $code->isa('Class::MOP::Method'))
		|| confess "Can only wrap blessed CODE";	
	my $modifier_table = { 
		cache  => undef,
		orig   => $code,
		before => [],
		after  => [],		
		around => {
			cache   => $code->body,
			methods => [],		
		},
	};
	$_build_wrapped_method->($modifier_table);
	my $method = $class->SUPER::wrap(sub { $modifier_table->{cache}->(@_) });	
	$method->{'%!modifier_table'} = $modifier_table;
	$method;  
}

sub get_original_method {
	my $code = shift; 
    $code->{'%!modifier_table'}->{orig};
}

sub add_before_modifier {
	my $code     = shift;
	my $modifier = shift;
	unshift @{$code->{'%!modifier_table'}->{before}} => $modifier;
	$_build_wrapped_method->($code->{'%!modifier_table'});
}

sub add_after_modifier {
	my $code     = shift;
	my $modifier = shift;
	push @{$code->{'%!modifier_table'}->{after}} => $modifier;
	$_build_wrapped_method->($code->{'%!modifier_table'});	
}

{
	# NOTE:
	# this is another possible canidate for 
	# optimization as well. There is an overhead
	# associated with the currying that, if 
	# eliminated might make around modifiers
	# more manageable.
	my $compile_around_method = sub {{
    	my $f1 = pop;
    	return $f1 unless @_;
    	my $f2 = pop;
    	push @_, sub { $f2->( $f1, @_ ) };
		redo;
	}};

	sub add_around_modifier {
		my $code     = shift;
		my $modifier = shift;
		unshift @{$code->{'%!modifier_table'}->{around}->{methods}} => $modifier;		
		$code->{'%!modifier_table'}->{around}->{cache} = $compile_around_method->(
			@{$code->{'%!modifier_table'}->{around}->{methods}},
			$code->{'%!modifier_table'}->{orig}->body
		);
		$_build_wrapped_method->($code->{'%!modifier_table'});		
	}	
}

1;

__END__

=pod

=head1 NAME 

Class::MOP::Method::Wrapped - Method Meta Object to handle before/around/after modifiers

=head1 SYNOPSIS

  # ... more to come later maybe

=head1 DESCRIPTION

=head1 METHODS

=head2 Construction

=over 4

=item B<wrap (&code)>

=item B<get_original_method>

=back

=head2 Modifiers

=over 4

=item B<add_before_modifier ($code)>

=item B<add_after_modifier ($code)>

=item B<add_around_modifier ($code)>

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

Yuval Kogman E<lt>nothingmuch@woobling.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2007 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

