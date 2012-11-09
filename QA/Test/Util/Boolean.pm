=begin NaturalDocs

    This is a Utility module for commonly used operations used in  QA::Test libraries;
    it allows people to more easily and effectively write automated web tests that are
    specific to QA. This module handles checks for true/false and bridges the gap
    for Perl's lack of a boolean type.
    
=cut
package QA::Test::Util::Boolean;

use strict;
use Carp qw(croak);
use Exporter 'import';
use Test::More;

=begin NaturalDocs

    Group: Copyright
	Copyright 2010, QA, All rights reserved.
    
    Author:
	Peter Salas
	
    About:

=cut

=begin NaturalDocs
 
    Group: Variables
 
    ARRAY: @EXPORT_OK
        Export of all the functions in this package to the user space. You will
	need to explitly export these functions. Example:
	
	(begin code)
	use QA::Test::Util::Boolean qw(isTrue);
	(end)
 
=cut

our @EXPORT_OK = qw(
    isTrue
);

=begin NaturalDocs

    Group: Boolean Verification
    
    Function: isTrue
	Checks whether given value (typically from an xml) is true.
	
    Parameters:
	value - any boolean value
    
    Returns:
	1 - (true) if value evaluates to true
	0 - (false) if value evaluates to false
	
    Note:
	The value could be in any of the following formats
	    - undef (null) ==> return 0
	    - true ==> return 1
	    - True ==> returns 1
	    - TRUE ==> returns 1
	    - 1 ==> returns 1
	    - false ==> returns 0
	    - False ==> returns 0
	    - FALSE ==> returns 0
	    - 0 ==> returns 0

=cut

sub isTrue #($value)
{
    my ($value) = @_;
    
    ## Return 0 if not defined
    return 0 unless defined $value;
    
    ## Check if value is proper format
    if ($value =~ m/^true$/i) {
	return 1;
    } elsif ($value =~ m/^false$/i) {
	return 0;
    } elsif ($value =~ m/^[+-]?\d+$/ and $value == 1) {
	return 1;
    } elsif ($value =~ m/^[+-]?\d+$/ and $value == 0) {
	return 0;
    } else {
	diag(qq|\$value is not a valid type boolean (true/false or 1/0) - value:'$value' ref:|.ref($value));
	return 0;
    }
    
}

1;
