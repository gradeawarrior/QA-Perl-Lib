=begin NaturalDocs

    This is a Utility module for commonly used operations used in  QA::Test libraries;
    it allows people to more easily and effectively write automated web tests that are
    specific to QA. This module helps with generating random values.
    
=cut
package QA::Test::Util::Random;

use strict;
use Carp qw(croak);
use Exporter 'import';
use POSIX;
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
	use QA::Test::Util::Random qw(genRandomKey genRandomAlphaKey);
	(end)
 
=cut

our @EXPORT_OK = qw(
    genRandomKey
    genRandomAlphaKey
    genRandomNumber
);

=begin NaturalDocs

    Group: Functions
    
    Function: genRandomKey
	Generates a random alpha-numeric STRING
	
    Parameters:
	str_length - (Optional) STRING length to generate. Default is 5 characters.
    
    Return:
	str - STRING containing the alpha-numeric random STRING

=cut

sub genRandomKey #($str_length)
{
    my ($str_length) = @_;
    
    $str_length = 5 unless defined $str_length;
    my @array = ('a'..'z','A'..'Z',0..9);
    my $string = '';
    srand;
    
    foreach (1..$str_length) {
	$string .= $array[int(rand scalar(@array))];
    }
    
    return $string;
}

=begin NaturalDocs

    Function: genRandomAlphaKey
	Generates a random alpha STRING
	
    Parameters:
	str_length - (Optional) STRING length to generate. Default is 5 characters.
    
    Return:
	str - STRING containing the alpha-numeric random STRING

=cut

sub genRandomAlphaKey #($str_length)
{
    my ($str_length) = @_;
    
    $str_length = 5 unless defined $str_length;
    my @array = ('a'..'z','A'..'Z');
    my $string = '';
    srand;
    
    foreach (1..$str_length) {
	$string .= $array[int(rand scalar(@array))];
    }
    
    return $string;
}

=begin NaturalDocs

    Function: genRandomNumber
	Returns a randomly generated round number from 0 to n where is n is argument passed
	
    Parameters:
	range - (Optional) Default is 100
    
    Return:
	number - a randomly generated round number from 0 to n where is n is argument passed

=cut

sub genRandomNumber #($range)
{
    my ($range) = @_;
    my $random_number;
    $range = 100 unless defined $range;
    $random_number = floor(rand($range));
    
    return $random_number;
}

1;