=begin NaturalDocs
 
    The main TestRunner class that handles execution of <QA::Test::TestSuite>'s
 
=cut
package QA::Test::TestRunner;

use strict;
use warnings;
use Carp qw(croak);
use Data::Dump qw(dump);
use IO::Tee;
use QA::Test;
use QA::Test::TestCase;
use QA::Test::Web::Selenium;
use QA::Test::Util::Boolean qw(isTrue);
use QA::Test::Util::Time qw(startTime elapsedTime);

=begin NaturalDocs
 
    Group: Copyright
        Copyright 2010, QA, All rights reserved.
 
    Author:
        Peter Salas
 
=cut

=begin NaturalDocs
 
    Group: Variables
 
    Member Variables:
        parameters - A user defined HASH-ARRAY structure containing any specific
            parameters needed to execute <QA::Test::TestSuite>
        results - A STRING that contains all raw Test::More output. This STRING
            can be later parsed to identify where errors or failures occured.
        debug - a STRING representing the <%DEBUG_LEVEL> that is set.
 
    Constant: $VERSION
        The current version of <QA::Test::TestRunner>
        
    Constant: %DEBUG_LEVEL
        A HASH containing the supported debug levels
        
            CLEAN - Will only print out which test subroutine passes or failes.
                It will not print the verifications or exceptions that lead to the
                failure.
            INFO - Similar to clean, but will print out the verifications that lead
                to the failure of the test subroutine.
            TRACE - This format will always print to STDOUT the currently executing
                test subroutine. This is useful for live debugging of the script.
            DEBUG - This will print all operations, including set_up and tear_down
                operations, to STDOUT.
 
=cut

our $VERSION = 1.00;
my %DEBUG_LEVEL = (
    CLEAN   => 1,
    INFO    => 1,
    TRACE   => 1,
    DEBUG   => 1
);

=begin NaturalDocs
 
    Group: Constructor
 
    Function: new
        Constructor for <QA::Test::TestRunner>
 
    Parameters:
        debug - Option for setting the debug level of the script execution. See <%DEBUG_LEVEL>
            for information on the supported values.
 
    Returns:
        A blessed reference of <QA::Test::TestRunner>
 
=cut

sub new #(debug => 'TRACE')
{
    my ($class, %args) = @_;
    my $self = {};
    bless($self, $class);
    
    ## Set Debug Level
    $self->set_debug_level($args{debug});

    ## Redirect results to a variable for parsing
    $self->{results} = [];
    $self->{results_str} = "";
    
    ## Create Selenium Reference
    my $ref = q|QA::Test::Web::Selenium|;
    $self->{sel_ref} = \$ref;

    return $self;
}

=begin NaturalDocs
 
    Group: Functions
 
    Function: set_parameters
        Checks if a given reference is an ARRAY
 
    Parameters:
         parameters - A hash-array reference
 
    Returns:
        None
 
=cut

sub set_parameters {
    my $self = shift;
    $self->{parameters} = { @_ };
    #print dump($self->{parameters}),"\n";
}

=begin NaturalDocs
 
    Function: run_tests
        Executes all tests within a given <QA::Test::TestSuite>
 
    Parameters:
         test_suite - A reference to a <QA::Test::TestSuite>
 
    Returns:
        None
 
=cut

sub run_tests #($test_suite)
{
    my $self = shift;
    my $test_suite = shift;
    my $func_name = (caller(0))[3];
    
    croak "test_suite not defined in $func_name!" unless defined $test_suite;

    my $parameters = $self->{parameters};
    my @test_args = %{ $parameters };
    #print dump(@test_args)."\n";
    
    foreach (@{ $test_suite->get_test_cases() }) {
        my $test_class = $_;
        add_test_class($test_class);
        #diag($DEBUG_MSG_CLASS."'$test_class' ********");
        
        # track total testcase timing info to save it result later in set_timing_info			
        my $runner_start_t0= startTime();
        
        # Execute Master Setup Operation only once
        my $master = $test_class->new(@test_args);
        $self->call_method($master, 'env_set_up') unless not defined &{"$master\::env_set_up"};

        foreach (@{ $test_suite->get_test_methods_for_test_case($test_class) }) {
            my $method_name = $_;
            my $test_obj    = $test_class->new(@test_args);
            $test_obj->{sel_ref} = $self->{sel_ref};
            $test_obj->set_test_subroutine($method_name);
            
            # Setup writing of data to log
            my $result = {
                class   => $test_class,
                name    => $method_name
            };
            push(@{$self->{results}}, $result);
            
            my $result_fh;
            my $setup_successful = 1;
            my $method_result = 1;
            my $eval = 1;
                        
            # track test method timing info to save it result later in set_timing_info
            my $test_start_t0 = startTime();

            # Attempt to do set_up subroutine
            if (defined &{"$test_class\::set_up"}) {
                $result->{set_up} = '';
                open $result_fh, '>', \$result->{set_up} or die "...$!";
                $self->set_debug("set_up", $result_fh);
                
                #$self->call_method($test_obj, "set_up");
                $setup_successful = $self->verify_results('set_up', $result, $self->call_method($test_obj, "set_up"));
                close $result_fh;
            }
            
            # Continue if set_up failed
            next if (not $setup_successful);
            
            # Only call the test method if set_up didn't create an error
            if ($setup_successful) {
                # Setup logging
                $result->{method} = '';
                open $result_fh, '>', \$result->{method} or die "...$!";
                $self->set_debug($method_name, $result_fh);
                
                # Call test method
                #$self->call_method($test_obj, $method_name);
                $self->verify_results($method_name, $result, $self->call_method($test_obj, $method_name));
                close $result_fh;
            }
            
            # Always call tear_down even if set_up or the test method has errors
            if (defined &{"$test_class\::tear_down"}) {
                $result->{tear_down} = '';
                open $result_fh, '>', \$result->{tear_down} or die "...$!";
                $self->set_debug("tear_down", $result_fh);
                
                #$self->call_method($test_obj, "tear_down");
                $self->verify_results('tear_down', $result, $self->call_method($test_obj, "tear_down"));
                close $result_fh;
            }
            
            # Close WebService Object
            $test_obj->{test_session}->stop() unless exists $test_obj->{test_session}->{elapsed};
        } # End iterate methods
        
        ## Stop Selenium
        ${$self->{sel_ref}}->stop() if (ref($self->{sel_ref}) ne "SCALAR" and ${$self->{sel_ref}}->isa("Test::WWW::Selenium"));
        $self->{execution_time} = elapsedTime($runner_start_t0);
    } # End iterate classes
    
    $self->report_execution();
    #dump($self->{results});
}

=begin NaturalDocs
 
    Function: call_method
        Executes a given subroutine with in <QA::Test::TestCase> class.
        This method is invoked by the run_tests() method and will traditionally
        iterate through all methods specified in <QA::Test::TestSuite>
        object (e.g. all functions that are prefixed with 'test_' and any
        'set_up' or 'tear_down' sub-routine as well).
 
    Parameters:
         test_obj - A reference to a <QA::Test::TestCase>
         method_name - The name of the method to execute on the test_obj reference
 
    Returns:
        1 - (true) if method execution is successful
        0 - (false) if method execution fails
 
=cut

sub call_method #($test_obj, $method_name)
{
    my ($self, $test_obj, $method_name) = @_;
    my $test_class = ref($test_obj);
    
    #print dump($test_obj)."\n";
    #return subtest ("$test_class\::$method_name" => \&{"$test_class\::$method_name"});
    
    add_test_case_method("$test_class\::$method_name()") unless ($method_name eq 'set_up' or $method_name eq 'tear_down');
    add_test_case_method("$test_class\::$method_name"."_$test_obj->{test_subroutine}()") if ($method_name eq 'set_up' or $method_name eq 'tear_down');
    my $response = 0;
    eval {
        $response = $test_obj->$method_name;
    };
    
    ## Check that there were no exceptions and return 1/0 (true/false) if successful or not.
    if ($@) {
        ok($response, $@);
        $self->reset_debug();
    } else {
        $self->reset_debug();
        $response = 1 if (not defined $response or $response eq '') ;
        return $response;
    }
}

=begin NaturalDocs

    Function: verify_results
    
    Parameters:
    
    Returns:

=cut

sub verify_results #()
{
    my ($self, $method_name, $result, $initial_result) = @_;
    
    croak "method_name not defined in ".(caller(0))[3] unless defined $method_name;
    croak "result not defined in ".(caller(0))[3] unless defined $result;
    $initial_result = 1 unless defined $initial_result;
    my $eval = 1;
    
    ## If test_ subroutine
    if ($method_name ne 'set_up' and $method_name ne 'tear_down') {
        # Set pass fail/rate
        my ($total, $pass, $fail);
        ($result->{method}, $total, $pass, $fail) = convert_to_hash_array($result->{method});
        $eval = $self->verify_testrunner_test( (not $fail and $initial_result), "$result->{class}\::$method_name");
        $result->{pass} = $eval;
        $result->{total} += $total;
        $result->{failures} += $fail;
    
    ## If set_up or tear_down
    } elsif ($method_name eq 'set_up' or $method_name eq 'tear_down') {
        my ($total, $pass, $fail);
        ($result->{$method_name}, $total, $pass, $fail) = convert_to_hash_array($result->{$method_name});
        $eval = ($initial_result and not $fail);
        $result->{total} += $total;
        $result->{failures} += $fail;
    }
    
    ## Print more diagnostic Output depending on debug level
    if (not $eval and $self->{debug} eq 'INFO' and $method_name ne 'set_up' and $method_name ne 'tear_down') {
        my ($str) = convert_to_test_more_string($result->{method});
        print $str;
    }
    elsif (not $eval and ($self->{debug} eq 'INFO' or $self->{debug} eq 'TRACE') and $method_name eq 'set_up' and $method_name ne 'tear_down') {
        $self->fail_test("$result->{class}\::$method_name");
        diag("Exception thrown in set_up subroutine");
        my ($str) = convert_to_test_more_string($result->{set_up});
        print $str;
    }
    
    #diag("method:'$method_name - initial:$initial_result eval:$eval");
    return $eval;
}

=begin NaturalDocs

    Function: set_debug
        Configures Test::More to stream appropriately to STDOUT, STDERR, and/or
        to a local variable. This is all controlled by the 'debug' attribute. See
        the constant <%DEBUG_LEVEL> for more information.
        
    Parameters:
        method - STRING representing the method that is currently being executed by TestRunner
        filehandles - An ARRAY of filehandles to output to.
        
    Returns:
        None

=cut

sub set_debug #($method, @filehandles)
{
    my ($self, $method_name, @filehandles) = @_;
    #push(@filehandles, \*STDERR);
    
    if ($self->{debug} =~ m/DEBUG/) {
        push(@filehandles, \*STDOUT);
    }
    elsif ($self->{debug} =~ m/TRACE/ and $method_name ne "set_up" and $method_name ne "tear_down") {
        push(@filehandles, \*STDOUT);
    }
    
    $self->{tee} = new IO::Tee(@filehandles);
    Test::More->builder->output($self->{tee});
    Test::More->builder->failure_output($self->{tee});
}

=begin NaturalDocs

    Function: reset_debug
        Configures Test::More to stream appropriately to STDOUT.
        
    Parameters:
        None
        
    Returns:
        None

=cut

sub reset_debug #()
{
    my ($self) = @_;
    Test::More->builder->output(\*STDOUT);
    Test::More->builder->failure_output(\*STDOUT);
}

=begin NaturalDocs

    Function: set_debug_level
        Sets the debug level of the TestRunner. If not set, the default behavior
        is to set to 'DEBUG' level.
        
    Parameters:
        debug - The debug level [CLEAN|INFO|TRACE|DEBUG]
        
    Returns:
        None

=cut

sub set_debug_level #($debug)
{
    my ($self, $debug) = @_;
    $self->{debug} = $debug;
    $self->{debug} = 'DEBUG' unless (defined $debug and exists $DEBUG_LEVEL{$debug});
}

sub pass_test #($description)
{
    my ($self, $description) = @_;
    return $self->verify_testrunner_test(1, $description);
}

sub fail_test #($description)
{
    my ($self, $description) = @_;
    return $self->verify_testrunner_test(0, $description);
}

sub verify_testrunner_test #($verification, $description)
{
    my ($self, $verification, $description) = @_;
    if ($verification) {
        print "PASS - $description\n";
        return 1;
    } else {
        print "FAIL - $description\n";
        return 0;
    }
}

=begin NaturalDocs

    Function: set_debug_level
        Sets the debug level of the TestRunner. If not set, the default behavior
        is to set to 'DEBUG' level.
        
    Parameters:
        debug - The debug level [CLEAN|INFO|TRACE|DEBUG]
        
    Returns:
        None

=cut

sub report_execution #()
{
    my ($self) = @_;
    my $total = @{$self->{results}};
    my $total_pass = 0;
    my $total_verifications = 0;
    my $verification_pass = 0;
    my $verification_fail = 0;
    my @failures = ();
    
    foreach my $test (@{$self->{results}}) {
        $total_pass += 1 if isTrue($test->{pass});
        push(@failures, "$test->{name} in $test->{class}") unless isTrue($test->{pass});
        
        $total_verifications += $test->{total};
        $verification_fail += $test->{failures};
        $verification_pass += ($test->{total} - $test->{failures});
    }
    my $total_failures = @failures;
    my $failure_rate = sprintf("%.3f", ($total_failures/$total) * 100) if $total;
    my $pass_rate = sprintf("%.3f", ($total_pass/$total) * 100) if $total;
    my $verification_fail_rate = sprintf("%.3f", ($verification_fail/$total_verifications) * 100) if $total;
    my $verification_pass_rate = sprintf("%.3f", ($verification_pass/$total_verifications) * 100) if $total;
    
    print <<EOF;
    
    Execution Statistics
    ====================
    Tests:
        - Execution Time:   $self->{execution_time} seconds
        - Total:            $total tests
        - Pass:             $total_pass tests ($pass_rate\%)
        - Fail:             $total_failures tests ($failure_rate\%)
    Verifications:
        - Total:            $total_verifications verified
        - Pass:             $verification_pass ok ($verification_pass_rate\%)
        - Fail:             $verification_fail not ok ($verification_fail_rate\%)
    
    Failed Tests:
EOF

    my $index = 1;
    foreach my $test (@failures) {
        print "        $index - $test\n";
        $index++;
    }
}

# can run testrunner on command line with arguments, checks the result of the caller() built-in function returns the calling package name
# caller is true if another Perl file loads this one with use() or require()
__PACKAGE__->run_tests(@_) unless caller;
1;
