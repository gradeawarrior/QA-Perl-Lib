=begin NaturalDocs

    This is a Utility module for commonly used operations used in  QA::Test libraries;
    it allows people to more easily and effectively write automated web tests that are
    specific to QA. This module helps to do logical comparisons.
    
=cut
package QA::Test::Util::Comparison;

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
	use QA::Test::Util::Time qw(startTime elapsedTime);
	(end)
 
=cut

our @EXPORT_OK = qw(
    compareBinaryFile
);

=begin NaturalDocs

    Function: compareBinaryFile
	Compares two binary files and checks if they are equal
    
    Parameters:
	file1 - First file
	file2 - Second file
	
    Returns:
	1 - (true) if equal
	0 - (false) if not the same

=cut

sub compareBinaryFile #($file1, $file2)
{
    my ($file1, $file2) = @_;
    
    croak 'file1 is not defined!' unless defined $file1;
    croak 'file2 is not defined!' unless defined $file2;
    diag("file1:'$file1' does NOT exist!") unless (-e $file1);
    diag("file2:'$file2' does NOT exist!") unless (-e $file2);
    return 0 unless (-e $file1);
    return 0 unless (-e $file2);
        
    my $size1 = -s $file1;
    my $size2 = -s $file2;
    my $ch1;
    my $ch2;
    my $i = 0 ;
    my $equal = 1;
    
    return 0 unless $size1 == $size2;
    
    open(FILE1,"<$file1") or die "Input file: Cannot open file1\n\n";
    open(FILE2,"<$file2") or die "Input file: Cannot open file2\n\n";
    
    # Iterate character by character through files
    while ($i < $size1) {
	$i ++ ;
	
	$ch1 = getc(FILE1);
	$ch2 = getc(FILE2);
	
	# Set $equal flag to 0 and exit loop if not equal
	if (not ($ch1 eq $ch2)) {
	    $equal = 0;
	    last;
	}
	
    } 
    
    # Close files
    close(FILE1);
    close(FILE2);

    return $equal;
}

1;
