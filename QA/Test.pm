=begin NaturalDocs
 
    This class extends the Test::More library and aims to (1) standardize Test Case
    outputs, and (2) the proper detection of passed/failed tests.
 
=cut
package QA::Test;

use strict;
use Test::More;
use Carp qw(croak);
use Exporter 'import';

=begin NaturalDocs
 
    Group: Copyright
        Copyright 2010, QA, All rights reserved.
 
    Author:
        Peter Salas
 
=cut

=begin NaturalDocs
 
    Group: Variables
    
    Array: @EXPORT
        Contains automatic exporting of all Test::More functions. In addition,
        the <QA::Test> subroutines are also automatically exported to the user's
        namespace.
 
    Constant: $VERSION
        The current version of <QA::Test::TestRunner>
 
    Constant: $DEBUG_MSG_CLASS
        Constant for debug message lines indicating when class's test methods
        are active in current execution
 
    Constant: $DEBUG_MSG_SUB
        Constant for debug message lines indicating specific method currently
        active in execution
 
=cut

our @EXPORT = qw(ok verify use_ok require_ok
             add_test_class add_test_case_method add_test_case
             convert_to_hash_array convert_to_test_more_string
             is_all_ok count_tests
             is isnt like unlike is_deeply
             cmp_ok
             skip todo todo_skip
             pass fail
             eq_array eq_hash eq_set
             $TODO
             plan
             can_ok  isa_ok
             diag
	     BAIL_OUT
            );

my $DEBUG_MSG_CLASS = "******** Testing Class ";
my $DEBUG_MSG_SUB = "-------->> Test Subroutine - ";
my $DEBUG_MSG_CASE = "========> Test Case - ";

=begin NaturalDocs
 
    Group: Functions
 
    Function: verify
        This subroutine is similar to the Test::More ok() subroutine call. The addition
        comes with the inclusion of the "actual_result" parameter that is
        automatically formatted into the Test::More output.
 
    Parameters:
         actual_result - The actual result
 
    Returns:
        1 (true) if successful, 0 (false) otherwise
 
=cut
            
sub verify #($condition, $test_name, $actual_result)
{
    my ($condition, $test_name, $actual_result) = @_;
    $test_name .= " - actual: $actual_result" unless not defined $actual_result;
    return ok($condition, $test_name);
}

=begin NaturalDocs
 
    Function: add_test_class
        Standardizes on the Test::More DEBUG or diagnostic output of a <TestCase> Class.
 
    Parameters:
         namespace - Users seeking to use this class should pass in the namespace
            of the <TestCase> class.
 
    Returns:
        None
 
=cut

sub add_test_class #($namespace)
{
    my ($test_class) = @_;
    diag($DEBUG_MSG_CLASS."'$test_class' ********");
}

=begin NaturalDocs
 
    Function: add_test_case_method
        Standardizes on the Test::More DEBUG or diagnostic output of a <TestCase> test subroutine.
 
    Parameters:
        method - Users seeking to use this class should pass in the test method
            of the <TestCase> class.
 
    Returns:
        None
 
=cut

sub add_test_case_method #($method)
{
    my ($method) = @_;
    diag($DEBUG_MSG_SUB.$method);
}

=begin NaturalDocs
 
    Function: add_test_case
        Standardizes on the Test::More DEBUG or diagnostic output of a test
 
    Parameters:
        description - A short description of the test
 
    Returns:
        None
 
=cut

sub add_test_case #($description)
{
    my ($description) = @_;
    diag($DEBUG_MSG_CASE.$description);
}

=begin NaturalDocs

    Function: is_all_ok
        A utility method that checks if the given String does not have any Test::More
        failures.
        
    Parameters:
        string - A string representing Test::More output
        
    Returns:
        1 (true) if there were no 'not ok' lines, 0 (false) otherwise

=cut

sub is_all_ok #($string)
{
    my ($string) = @_;
    foreach my $line (split(/\n/, $string)) {
        return 0 unless $line !~ m/^not\s+ok/;
    }
    return 1;
}

=begin NaturalDocs

    Function: count_tests
        Counts the number of Test::More Tests
        
    Parameters:
        string - A string representing Test::More output
        
    Returns:
        An array with the following
        
        total - The total number of tests
        ok - The total number of pass
        not ok - The total number of failures

=cut

sub count_tests #($string)
{
    my ($string) = @_;
    my $total = 0;
    my $pass = 0;
    my $fail = 0;
    
    foreach my $line (split(/\n/, $string)) {
        $pass += 1 if $line =~ m/^not\s+ok/;
        $fail += 1 if $line =~ m/^ok/;
        $total = $pass + $fail;
    }
    
    return ($total, $pass, $fail);
}

=begin NaturalDocs

    Function: convert_to_hash_array
        Converts the Test::More output to a HASH-ARRAY of the following format.
        
        (begin code)
        [
            {
                pass => [1|0],
                description => "Some Test::More message"
            },
            {
                description => "Some Test::More or other debug message"
            }
        ]
        (end)
        
    Parameters:
        string - A string representing Test::More output
        
    Returns:
        An array with the following
        
        reference - A HASH-ARRAY reference
        total - The total number of tests
        ok - The total number of pass
        not ok - The total number of failures

=cut

sub convert_to_hash_array #($string)
{
    my ($string) = @_;
    my @array = ();
    my $pass = 0;
    my $fail = 0;
    my $total = 0;
    my $description;
    my $temp_debug_class = $DEBUG_MSG_CLASS;
    $temp_debug_class =~ s/\*/\\*/g;
    
#my $DEBUG_MSG_CLASS = "******** Testing Class ";
#my $DEBUG_MSG_SUB = "-------->> Test Subroutine - ";
#my $DEBUG_MSG_CASE = "========> Test Case - ";
    
    foreach my $line (split(/\n/, $string)) {
        ## If 'not ok' line
        if ($line =~ m/^not\s+ok\s+\d*\s*-\s+(.*)/) {
            $description = $1;
            push(@array, { pass=>0, description=>$description } );
            $fail+=1;
        }
        
        ## If 'ok' line
        elsif ($line =~ m/^ok\s+\d*\s*-\s+(.*)/) {
            $description = $1;
            push(@array, { pass=>1, description=>$description } );
            $pass+=1;
            
        ## If 'diagnostic' or '#' line
        } elsif ($line =~ m/^#\s+(.*)/) {
            $description = $1;
            
            # Append Diagnostic message
            if (@array > 0 and not defined $array[-1]->{pass} and $array[-1]->{description} !~ m/$temp_debug_class/ and $array[-1]->{description} !~ m/$DEBUG_MSG_SUB/ and $array[-1]->{description} !~ m/$DEBUG_MSG_CASE/) {
                $array[-1]->{description} .= "\n$description";
            # Add Diagnostic message
            } else {
                push(@array, { description=>$description } );
            }
        } else {
            
            if (@array > 0 and defined $array[-1]->{type} and $array[-1]->{description} !~ m/$temp_debug_class/ and $array[-1]->{description} !~ m/$DEBUG_MSG_SUB/ and $array[-1]->{description} !~ m/$DEBUG_MSG_CASE/) {
                $array[-1]->{description} .= "\n$line";
            } else {
                push(@array, { description=>$line, type=>'other' } );
            }
        }
        $total = $pass + $fail;
    }
    
    return (\@array, $total, $pass, $fail);
}

=begin NaturalDocs

    Function: convert_to_test_more_string
        Converts the Test::More output to a HASH-ARRAY of the following format.
        
        (begin code)
        [
            {
                pass => [1|0],
                description => "Some Test::More message"
            },
            {
                description => "Some Test::More or other debug message"
            }
        ]
        (end)
        
    Parameters:
        string - A string representing Test::More output
        
    Returns:
        An array with the following
        
        reference - A STRING representing the TEST::More formatted output
        total - The total number of tests
        ok - The total number of pass
        not ok - The total number of failures

=cut

sub convert_to_test_more_string #($hash_array_ref)
{
    my ($hash_array_ref) = @_;
    my $return_str = "";
    my $index = 1;
    my $pass = 0;
    my $fail = 0;
    my $total = 0;
    #diag("orig:'$hash_array_ref' and ref:".ref($hash_array_ref));
    return ($hash_array_ref, $total, $pass, $fail) if (ref($hash_array_ref) ne 'ARRAY');
    
    foreach my $test (@{$hash_array_ref}) {
        $return_str .= "ok - $test->{description}\n" if (defined $test->{pass} and $test->{pass});
        $return_str .= "not ok - $test->{description}\n" if (defined $test->{pass} and not $test->{pass});
        $index += 1 if (defined $test->{pass});
        
        if (not defined $test->{pass}) {
            foreach my $debug_msg (split(/\n/, $test->{description})) {
                $return_str .= "#   $debug_msg\n";
            }
        }
    }
    
    return ($return_str, $total, $pass, $fail);
}

1;
