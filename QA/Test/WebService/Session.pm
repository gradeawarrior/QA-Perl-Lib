=begin NaturalDocs

    A Perl module wrapper around the popular LWP libraries, which provides
    common tools around testing WebServices endpoints.
    
=cut
package QA::Test::WebService::Session;

use strict;
use Carp qw(croak);
use HTML::Entities qw(encode_entities);
use JSON::XS;
use QA::Test::Util::Time qw(startTime elapsedTime);
use QA::Test::WebService qw(request);
use Test::More;

=begin NaturalDocs

    Group: Copyright
	Copyright 2010, QA, All rights reserved.
    
    Author:
	Peter Salas
	
    Synopsis:
	(begin code)
	    use strict;
	    use Carp qw(croak);
	    use Data::Dump qw(dump);
	    use JSON::XS;
	    use Test::More;
	    use QA::Test::WebService::Session;
	    
	    my $test_session = QA::Test::WebService::Session->new();
	    $test_session->start();
	    my $eval = $test_session->runTest(
		{
		    'testname'    =>    'Hit Google',
		    'method'    =>    'GET',
		    'url'    =>    "http://www.google.com",
		    'validations'  =>    [
					    {  
						'validation_key'    =>  { 'type' => 'code' },
						'validation_value'  =>  qr|200|
					    },
					    {
						'validation_key'    =>  { 'type' => 'content' },
						'validation_value'  =>  q|<html>|
					    },
					    {
						'validation_key'    =>  { 'type' => 'header',
								  'name' => 'Content-Type'
								},
						'validation_value'  =>  q|text/html|
					}
					]
		}
	    );
	    
	    $eval = $test_session->runTest(
		{
		    'testname'    =>    'Hit Farmd Test 1',
		    'method'    =>    'POST',
		    'url'    =>    q|http://10.22.105.62:1335/v1/message?av&spam&av&spam&from=foo@example.com&rcpt1=foo@example.net&ip=10.0.0.1&cid=edn.12345|,
		    'request_body' =>     qq|/Users/psalas/dev/data/qa-spam-msgs/sa-spam.1|,
		    'validations'  =>    [
					    {  
						'validation_key'    =>  { 'type' => 'code' },
						'validation_value'  =>  q|200|
					    },
					    {
						'validation_key'    =>  { 'type' => 'content' },
						'validation_value'  =>  q|spam_classifier|
					    },
					    {
						'validation_key'    =>  { 'type' => 'content' },
						'validation_value'  =>  q|spam_mlxscore|
					    },
					    {
						'validation_key'    =>  { 'type' => 'content' },
						'validation_value'  =>  q|av_result|
					    },
					]
		}
	    );
	    my $response = $test_session->get_response();
	    my $response_content =  decode_json($response->content());
	    $test_session->verify_test($response_content->{spam_classifier} eq "spam", "Classifier Spam is Spam", 'spam');
	    $test_session->verify_test(100 == $response_content->{spam_mlxscore}, "MLX Score of Spam mail is 100", 100);
	    $test_session->verify_test($response_content->{av_result} eq "clean", "Classifier AV is clean", 'clean');
	    
	    $test_session->stop();
	(end)

    Group: See Also
    
	For a more lightweight WebServices Request, see <QA::Test::WebService>. This class
	uses this library to make a webservice request.

=cut

=begin NaturalDocs

    Group: Variables
    
    Attributes:
	start_time - The start time of this Session. This is only set after <start()> is called.
	stop_time - The stop time of this Session. This is only set after <stop()> is called.
	elapsed - The elapsed amount of time between <start()> and <stop()>.
	results - A HASH-ARRAY reference containing the results, including verifications, of
	    all tests.
	total_cases - The number of results
	failed_cases - The number of tests that fail. A failure is considered if any 1 verification
	    of a request fails.
	disable_response - This is only when generating an HTML, JSON, or any other export
	    file. You can exclude the response body of a request which may be too verbose in
	    a report.
	response - This is the last HTTP::Response that was returned from doing a request.
    
    Constant: $UNKNOWN_STATE
	A constant string that represents an 'unknown' state. This should not be
	modified

=cut

my $UNKNOWN_STATE = 'unknown';

=begin NaturalDocs

    Group: Constructor
    
    Function: new
	instantiates a new QA::Test::WebService::Session object.
    
    Parameters:
	None
    
    Return:
	A reference to QA::Test::WebService::Session
	
=cut

sub new #()
{
    my($class, %args) = @_;
    my $self = bless({}, $class);    

    $self->{start_time} = undef;
    $self->{start_t0} = undef;
    $self->{stop_time} = undef;
    $self->{results} = [];
    $self->{total_cases} = 0;
    $self->{failed_cases} = 0;
    $self->{disable_response} = 0;
    
    $self->{var} = {};
    
    $self->{operator_hash} = {
	'eq' => "==",
	'ge' => ">=",
	'le' => "<=",
	'gt' => ">",
	'lt' => "<"
    };
    
    $self->{value_type} = ['NUMBER', 'STRING'];
    
    $self->{pass_fail_hash} = {
	1 => 'PASS',
	0 => 'FAIL'
    };

    return $self;
}

=begin NaturalDocs

    Group: Functions
    
    Function: disable_unit_tests
	Turns off all Test::More output and redirects them to $test_session->{unit_tests} variable.
    
    Parameters:
	None
    
    Return:
	None

=cut

sub disable_unit_tests #()
{
    my ($self) = @_;

    ## Redirect results to a variable for parsing
    $self->{unit_tests} = "";
    $self->{unit_test_fh} = undef;
    
    open $self->{unit_test_fh}, '>', \$self->{unit_tests} or die "...$!";
    Test::More->builder->output($self->{unit_test_fh});
    Test::More->builder->failure_output($self->{unit_test_fh});
}

=begin NaturalDocs
    
    Function: disableResponse
	Turns off printing of the Response(s) from the Web Request(s) in the html format
    
    Parameters:
	None
    
    Return:
	None

=cut

sub disableResponse #()
{
    my $self = shift;
    $self->{disable_response} = 1;
}

=begin NaturalDocs
    
    Function: start
	Starts the timing of all WebService requests for this Session. Start time
	is noted in $test_session->{start_time}.
    
    Parameters:
	None
    
    Return:
	None

=cut

sub start #()
{
    my $self = shift;
    $self->{start_time} = localtime();
    $self->{start_t0} = startTime();
}

=begin NaturalDocs
    
    Function: stop
	Stops the timing of all WebService requests for this Session. Stop time
	is noted in $test_session->{stop_time} and total elapsed time since start
	is in $test_session->{elapsed}.
    
    Parameters:
	None
    
    Return:
	None

=cut

sub stop #()
{
    my $self = shift;
    $self->{stop_time} = localtime();
    $self->{elapsed} = elapsedTime($self->{start_t0});
}

=begin NaturalDocs
    
    Function: runTest
	Executes a web request and performs validations.
    
    Parameters:
	A hash with the following key/values:
	
	testname - A description that describes what is being performed.
        method - Method for the http call. Valid methods are: [GET|POST|PUT|DELETE]
        timeout - (Optional) The timeout in seconds for the request. The default value is 180 seconds.
	url - Fully qualified url of the endpoint/api, including the"http://" in it.
        headers - (Optional) Hash of headers to pass into the call.
	request_body - (Optional) The Request body to insert into the Web Request. If the
	    value set here represents a file, then the contents of the file are
	    posted.
        content-type - (Optional) Specifies the Content-Type of this request.
	validations - (Optional) An array of hash references representing the various out-of-the-box
	    validations that can be performed on the Web Response
	
    Return:
    	1 (true) if request is successful and all validations, 0 (false) otherwise. At least 1 Test::More verification
	will be executed signifying that the request took place or not. However, a 0 (false) failure
	may still be returned because the request failed (e.g. There is something wrong with the URL and thus
	returned immediately).
	
    Example:
	(begin code)
	
	my $eval = $test_session->runTest(
	    'testname'    =>    'Hit Google',
	    'method'    =>    'GET',
	    'url'    =>    "http://www.google.com",
	    'validations'  =>    [
		    {  
			'validation_key'    =>  { 'type' => 'code' },
			'validation_value'  =>  qr|200|
		    },
		    {
			'validation_key'    =>  { 'type' => 'content' },
			'validation_value'  =>  q|<html>|
		    },
		    {
			'validation_key'    =>  { 'type' => 'header',
					  'name' => 'Content-Type'
					},
			'validation_value'  =>  q|text/html|
		    }
	    ]
	);
	(end)

=cut

sub runTest #($hash_ref)
{
    my ($self, %dataref) = @_;
    
    # Check Required Variables
    return 0 unless defined $dataref{url};
    
    $self->{'total_cases'}++;
    my $eval = 1;
    
    ###################################
    # Create new HTTP::Request Object #
    ###################################
    
    # Retrieve the domain whether that be an IP (e.g, 10.18.56.81) or a url (e.g, www.google.com)
    my $domain = $dataref{'url'};
    $domain =~ s/http:\/\/([0-9a-zA-Z.].*?)(\/|:\d+).*/$1/;
    
    $self->{response} = request(
	method		=> $dataref{method},
	timeout		=> $dataref{timeout},
	url		=> $dataref{url},
	headers		=> $dataref{headers},
	request_body	=> $dataref{request_body}
    );
    my $elapsed = $self->{response}->{elapsed};
    
    ############################
    # Perform validation tests #
    ############################
    
    # Create a temp hash to store the results in the Session Object
    my $test_name = $domain . qq| - | . $dataref{'testname'};
    push(@{$self->{results}},
	{
	    'url'		=>  $dataref{url},
	    'method'		=> $dataref{method},
	    'testname'		=>  $test_name,
	    'status'		=>  1,
	    'exec_time'		=>  $elapsed,
	    'response'		=>  $self->{response},
	    'validations'	=>  []
	}
    );
    $eval = (ok(defined $self->{response}, "$test_name Took $elapsed seconds") and $eval);
    $eval = ($self->{response}->is_success and $eval);
    diag("Request Failure!") unless $self->{response}->is_success;
    $eval = ($self->execute_validations(\%dataref) and $eval) if defined $self->{response};
    
    # Return 1 (true) if successful and 0 (false) otherwise
    return $eval;
}

=begin NaturalDocs

    Function: get_last_test
	Retrieves the results of the last Web Request executed.
    
    Parameters:
	None
    
    Return:
	A hash reference representing the last test executed

=cut

sub get_last_test #()
{
    my ($self) = @_;
    my $num_results = @{$self->{results}};
    return if $num_results < 1;
    return $self->{results}->[$num_results-1];
}

=begin NaturalDocs

    Function: get_response
	Returns the Response from the last test
	
    Parameters:
	None
	
    Returns:
	The HTTP::Response reference or undef if there are no tests executed yet.

=cut

sub get_response #()
{
    my ($self) = @_;
    return $self->{response};
}

=begin NaturalDocs

    Group: Verifications
    
    Function: execute_validations
	Executes the out-of-the-box validations on the WebRequest specified in <runTest>.
    
    Parameters:
	request - The hash reference specified in <runTest> subroutine.
    
    Return:
	1 (true) if all validations are successful, 0 (false) otherwise.

=cut

sub execute_validations #($request)
{
    my ($self, $dataref) = @_;
    
    my $eval = 1;
    foreach (@{$dataref->{'validations'}}) {
        my $validationHash = {};
        
        if ($_->{validation_key}->{'type'} eq 'code') {
	    $eval = ($self->verify_code($_->{validation_value}, $_->{not}) and $eval);
        } elsif ($_->{validation_key}->{'type'} eq 'message') {
	    $eval = ($self->verify_message($_->{validation_value}) and $eval);
        } elsif ($_->{validation_key}->{'type'} eq 'content') {
	    $eval = ($self->verify_content(
		content		=> $_->{validation_value},
		description	=> $_->{description},
		not		=> $_->{not},
		type		=> $_->{check}->{type},
		operator	=> $_->{check}->{operator},
		value		=> $_->{check}->{value}
	    ) and $eval);
        } elsif ($_->{validation_key}->{'type'} eq 'header') {
	    $eval = ($self->verify_header($_->{validation_key}->{name}, $_->{validation_value}) and $eval);
        } elsif ($_->{validation_key}->{'type'} eq 'timeout') {
	    $eval = ($self->verify_timeout($_->{validation_value}) and $eval);
	}
    }
    
    return $eval;
}

=begin NaturalDocs
    
    Function: verify_code
	Verifies that the last Web Request has specified Response Code.
    
    Parameters:
	code - The expected response code
	not - (Optional) Specifies if checking NOT the specified response code (e.g. NOT 500) - Default is 0 (false)
    
    Return:
	1 (true) if successful, 0 (false) otherwise

=cut

sub verify_code #($code, $not)
{
    my ($self, $code, $not) = @_;
    croak 'code is undefined in QA::Test::WebService::Session::verify_code()!' unless $code;
    
    my $validation_key = {type=>'code'};
    my $evaluation;
	
    return fail("There is no response from server") unless defined $self->{response};
    my $actual_code = $self->{response}->code();
    if (defined $not and $not) {
	$evaluation = $actual_code !~ $code;
	return $self->verify_test($evaluation, "Response code is NOT $code - actual: $actual_code", $code, $validation_key);
    } else {
	$evaluation = $actual_code =~ $code;
	return $self->verify_test($evaluation, "Response code is $code - actual: $actual_code", $code, $validation_key);
    }
}

=begin NaturalDocs
    
    Function: verify_header
	Verifies that the last Web Request has the specified header and value.
    
    Parameters:
	header - The header to check
	value - The value to check
    
    Return:
	1 (true) if successful, 0 (false) otherwise

=cut

sub verify_header #($header, $value)
{
    my ($self, $header, $value) = @_;
    croak 'header is not defined in QA::Test::WebService::Session::verify_header()!' unless defined $header;
    croak 'value is not defined in QA::Test::WebService::Session::verify_header()!' unless defined $value;
    
    return fail("There is no response from server") unless defined $self->{response};
    my $header_value = $self->{response}->header($header);
    my $evaluation = $header_value =~ $value;
    return $self->verify_test($evaluation, "$header: $value - actual: $header_value", $value, {type=>'header', name=>$header});
}

=begin NaturalDocs
    
    Function: verify_message
	Verifies that the last Web Request has the specified message
    
    Parameters:
	message - the response message
    
    Return:
	1 (true) if successful, 0 (false) otherwise

=cut

sub verify_message #($message)
{
    my ($self, $message) = @_;
    croak 'message is not defined in QA::Test::WebService::Session::verify_message()!' unless defined $message;
    
    return fail("There is no response from server") unless defined $self->{response};
    my $actual_message = $self->{response}->message();
    my $evaluation = $actual_message =~ $message;
    return $self->verify_test($evaluation, "Message is $message - actual: $actual_message", $message, {type=>'message'});
}

=begin NaturalDocs
    
    Function: verify_content
	Verifies that the last Web Request has the specified message
    
    Parameters:
	content - The content to check if the Response Content body contains
	not - (Optional) checks the non-existence of content - Default is 0 (false)
	description - (Optional) An optional description which describes this validation
    
    Return:
	1 (true) if successful, 0 (false) otherwise

=cut

sub verify_content #(content=>'foo', not=>0, description=>"Bar")
{
    my ($self, %args) = @_;
    croak 'content is not defined in QA::Test::WebService::Session::verify_content()!' unless exists $args{content};
    
    my $description;
    $description = "Message contains $args{content}" if not defined $args{description} and not $args{not};
    $description = "Message does NOT contain $args{content}" if not defined $args{description} and defined $args{not} and $args{not};
    $description = $args{description} if $args{description};
    
    return fail("There is no response from server") unless defined $self->{response};
    my $actual_content = $self->{response}->content();
    my $validation_key = {type=>'content'};
    my $evaluation;
    my $value;
	
    ## Sophisticated regular expression check if there is a tag called 'check'
    if (defined $args{type} and defined $args{operator} and defined $args{value} and $actual_content =~ m/$args{content}/) {
	$evaluation = check($1, $args{type}, $args{operator}, $args{value});
	$value = qq|$args{content}: $1($args{type}) $self->{operator_hash}->{$args{operator}} $args{value}($args{type})|;
	return $self->verify_test($evaluation, $description, $value, $validation_key);
    }
    
    ## Simple regular expression check of type content for the non-existence of value
    elsif (defined $args{not}) {
	$evaluation = $actual_content !~ $args{content};
	$value = "args{content} NOT";
	return $self->verify_test($evaluation, $description, $value, $validation_key);
    }
    
    ## Simple regular expression check of type content for existence of value
    else {
	$evaluation = $actual_content =~ $args{content};
	$value = $args{content};
	return $self->verify_test($evaluation, $description, $value, $validation_key);
    }
}

=begin NaturalDocs
    
    Function: verify_timeout
	Verifies that the last Web Request took less than specified timeout.
    
    Parameters:
	timeout - The time in milliseconds
    
    Return:
	None

=cut

sub verify_timeout #(20000)
{
    my ($self, $timeout) = @_;
    my $func = (caller(0))[3];
    croak 'timeout is not defined in $func!' unless defined $timeout;
    
    return fail("There is no response from server") unless defined $self->{response};
    my $execution_time = $self->get_last_test()->{exec_time};
    my $evaluation = check($execution_time, "NUMBER", 'le', $timeout);
    
    my $desc = "Call took <= $timeout";
    my $value = qq|$execution_time le $timeout - actual: $execution_time|;
    my $validation_key = {type=>'timeout'};
    return $self->verify_test($evaluation, $desc, $value, $validation_key);
}

=begin NaturalDocs
    
    Function: verify_test
	A helper sub-routine that generalizes all verify test sub-routines.
    
    Parameters:
	evaluation - an evaluation of true/false (1/0)
	description - Description of the test
	value - (Optional) The expected value that is being checked. Default is set to 'unknown'
	validation_key - (Optional) An internal structure representing what is being verified
    
    Return:
	Returns 1 (true) if evaluation is true, or 0 (false) otherwise

=cut

sub verify_test #($evaluation, $description, $value, $validation_key)
{
    my ($self, $evaluation, $description, $value, $validation_key) = @_;
    my $func = (caller(0))[3];
    
    croak 'evaluation is not defined in $func!' unless defined $evaluation;
    croak 'description is not defined in $func!' unless defined $description;
    
    $validation_key = {type=>'user_defined'} unless $validation_key;
    $value = $UNKNOWN_STATE unless defined $value;
    my $validation;
    
    if ($evaluation) {
	pass("$description");
	$validation = $self->create_validation_hash($description, $validation_key, $value, 1);
	return $self->pass_test($validation);
    } else {
	fail("$description");
	$validation = $self->create_validation_hash($description, $validation_key, $value, 0);
	return $self->fail_test($validation);
    }
}

=begin NaturalDocs
    
    Function: create_validation_hash
	A utility sub-routine that sets up an innitial hash structure for all Web Request
	validations. Note that this sub-routine should not be called externally.
    
    Parameters:
	description - A description of the validation
	validation_key - An internal structure representing the type of validation
	validation_value - The expected value
	status - (Optional) Represents the internal state of the test - default is set to 'unknown'
    
    Return:
	A hash reference representing the validation

=cut

sub create_validation_hash #($description, $validation_key, $validation_value, $status)
{
    my ($self, $description, $validation_key, $validation_value, $status) = @_;
    
    return {
	'description'       =>  $description,
	'validation_key'    =>  $validation_key,
	'validation_value'  =>  $validation_value,
	'status'            =>  $UNKNOWN_STATE		# Global var that is set to 'unknown'
    } unless defined $status;
    return {
	'description'       =>  $description,
	'validation_key'    =>  $validation_key,
	'validation_value'  =>  $validation_value,
	'status'            =>  $status
    };
}

=begin NaturalDocs
    
    Function: pass_test
	A utility sub-routine that marks a validation as passed. Note that this sub-routine should not be called externally.
    
    Parameters:
	validation - The hash reference representing the validation
    
    Return:
	Returns 1 (true)

=cut

sub pass_test #($validation)
{
    my ($self, $validation) = @_;
    croak 'validation is undefined in QA::Test::WebService::Session::pass_test()!' unless $validation;
    
    my $test = $self->get_last_test();
    $validation->{'status'} = 1;
    push(@{$test->{'validation'}}, $validation);
    return 1;
}

=begin NaturalDocs
    
    Function: fail_test
	A utility sub-routine that marks a validation as failed. Note that this sub-routine should not be called externally.
    
    Parameters:
	validation - The hash reference representing the validation
    
    Return:
	Returns 0 (false)

=cut

sub fail_test #($validation)
{
    my ($self, $validation) = @_;
    croak 'validation is undefined in QA::Test::WebService::Session::fail_test()!' unless $validation;
    
    ## FAIL The entire test and increment failure count if not done already
    my $test = $self->get_last_test();
    if ($test->{status} == 1 or $test->{status} eq $UNKNOWN_STATE) {
	$test->{status} = 0;
	$self->{'failed_cases'}++;
    } else {
	$test->{'status'} = 0;
    }
    
    ## Set Validation to FAIL and add to Test
    $validation->{'status'} = 0;
    push(@{$test->{'validation'}}, $validation);
    return 0;
}

#sub saveVar {
#    my $self = shift;
#    my $hash = shift;
#    my $var = shift;
#    
#    if (defined $hash->{save}) {
#	my $var_name = $hash->{save};
#	uself->{var}->{$var_name} = $var;
#	return 1;
#    }
#    return 0;
#}

=begin NaturalDocs
    
    Function: check
	Method used for performing more sophisticated regular expression check for equality (Deprecated).
	
    Parameters:
	value - The actual value
	type - specifies whether to do a string or numeric equality [NUMBER|STRING].
	operator - The operator to perform [lt|le|eq|gt|ge].
	test_value - The expected value
	
    Return:
	1 (true) if successful, 0 (false) otherwise

=cut

sub check #($value, $type, $operator, $test_value)
{
    my $self = shift;
    my $value = shift;
    my $type = shift;
    my $operator = shift;
    my $test_value = shift;
    
    return 0 unless defined $value;
    return 0 unless defined $type;
    return 0 unless defined $operator;
    return 0 unless defined $test_value;
    
    ## Check if type NUMBER
    if ($type eq $self->{value_type}->[0]) {
        if ($operator eq 'lt') {
                if ($value < $test_value) {
                return 1;
                }
        } elsif ($operator eq 'gt') {
                if ($value > $test_value) {
                    return 1;
                }
        } elsif ($operator eq 'ge') {
                if ($value >= $test_value) {
                    return 1;
                }
        } elsif ($operator eq 'le') {
                if ($value <= $test_value) {
                    return 1;
                }
        } elsif ($operator eq 'eq') {
                if ($value == $test_value) {
                    return 1;
                }
	} elsif ($operator eq 'ne') {
	    if ($value != $test_value) {
		return 1;
	    }
        } else {
                croak "undefined operator '$operator'!";
        } # End $operator switch
        
        ## Return False if none of the above checks pass
        return 0;
    } # End NUMBER type
    ## Check if type STRING
    else {
        if ($operator eq 'lt') {
                if ($value lt $test_value) {
                return 1;
                }
        } elsif ($operator eq 'gt') {
                if ($value gt $test_value) {
                    return 1;
                }
        } elsif ($operator eq 'ge') {
                if ($value ge $test_value) {
                    return 1;
                }
        } elsif ($operator eq 'le') {
                if ($value le $test_value) {
                    return 1;
                }
        } elsif ($operator eq 'eq') {
                if ($value eq $test_value) {
                    return 1;
                }
	} elsif ($operator eq 'ne') {
		if ($value ne $test_value) {
		    return 1;
		}
        } else {
                croak "undefined operator '$operator'!";
        } # End $operator switch
        
        ## Return False if none of the above checks pass
        return 0;
    } # End STRING type
}

=begin NaturalDocs

    Group: Result Formatting
    
    Function: getJSONResults
	Returns a formatted JSON string of all test results.
    
    Parameters:
	None
	
    Return:
	A JSON string
	
=cut

sub getJSONResults #()
{
    my $self = shift;
    my $pretty = shift;
    
    ## Create simplified structure for JSON 'tests' response
    my @tests_array = ();
    foreach my $result (@{$self->{results}}) {
	my $result_hash = {
	    'url'		=> $result->{url},
	    'method'		=> $result->{method},
	    'testname'		=> $result->{testname},
	    'status'		=> $self->{pass_fail_hash}->{$result->{status}},
	    'response_code'	=> $result->{response}->code() . ' ' . $result->{response}->message(),
	    'execution_time'	=> $result->{exec_time}
	};
	
	my @validation_array = ();
	foreach my $validation (@{$result->{validation}}) {
	    # Add only validations that fail to json response
	    if ($validation->{status} != 1) {
		my $validation_hash = {
		    #'status'	=> $self->{pass_fail_hash}->{$validation->{status}},
		    'description'	=> $validation->{description}
		};
		
		push(@validation_array, $validation_hash);
	    }
	}
	
	# Add validation array to the test result hash
	$result_hash->{failed_validations} = \@validation_array;
	
	# Add result hash to the list of tests
	push(@tests_array, $result_hash);
    }

    my $json_hash = {
		     'start_time'	=> $self->{start_time},
		     'stop_time'	=> $self->{stop_time},
		     'elapsed'		=> $self->{elapsed},
		     'total_cases'	=> $self->{total_cases},
		     'pass_count'	=> $self->{total_cases} - $self->{failed_cases},
		     'failed_count'	=> $self->{failed_cases},
		     'tests'		=> \@tests_array
    };
    
    my $json_txt;
    if (defined $pretty) {
	$json_txt = JSON::XS->new->pretty(1)->encode ($json_hash);
    } else {
	$json_txt = JSON::XS->new->pretty(0)->encode ($json_hash);
    }
    
    return $json_txt;
}

=begin NaturalDocs
    
    Function: getHTMLResults
	Returns a formatted HTML string of all test results.
    
    Parameters:
	None
	
    Return:
	A HTML string
	
=cut

sub getHTMLResults #()
{
    my $self = shift;
    my $html = undef;
    
    $html = <<ENDOFHTML;
    <html>
    <head>
    <script language="javascript">
        function show(id) {
            if (document.getElementById(id).className == "hide") {
                document.getElementById(id).className = "show";
                document.getElementById("span"+id).innerHTML = "-";
            } else {
                document.getElementById(id).className = "hide";
                document.getElementById("span"+id).innerHTML = "+";
            }
        }
    </script>
    <style>
    .hide { visibility: hidden; display: none }
    .show { visibility: visible; display: '' }
    </style>
    </head>
    <body>
    <a name="top"></a>
    <br>
ENDOFHTML

    $html .= "<b>Start Time:</b>" . $self->{'start_time'} . " (GMT)<br/>\n";
    $html .= "<b>End Time: </b>" . $self->{'stop_time'} . " (GMT)</br>\n";
    $html .= "<b>Elapsed Time: </b>" . $self->{'elapsed'} . " seconds</br>\n";
    
    $html .= "<b>Total: </b>" . $self->{'total_cases'} . qq| \| <font color="009900"><b>Passed:</b></font> | . ($self->{'total_cases'} - $self->{'failed_cases'}) . qq| \| <font color="FF0000"><b>Failed:</b></font> | . $self->{'failed_cases'} . "<br>\n";
    if ($self->{failed_cases}) {
        my $failed_count = 1;
        $html .= "<b>Failed Tests:</b> \n";
        foreach my $result (@{$self->{results}}) {
            unless ($result->{'status'}) { $html .= qq|[<a href="#ref| . $failed_count . qq|">| . $failed_count . qq|</a>]| };
		$failed_count++;
        }
    }
    $html .= "\n<hr>\n";

    #=======================#
    # Test execution starts #
    #=======================#
    my $total_count = 0;
    my @failed_tests = ();

    $html .= qq|<table border="0">| . "\n";
    foreach my $result (@{$self->{results}}) {
        # Prepare the data for the tests
        $total_count++;
        my $sub_count = 1;
        
        # Print test summary
        $html .= $total_count%2 == 0? "<tr bgcolor=\"CCCCFF\"><td>\n" : "<tr bgcolor=\"DDDDDD\"><td>\n";
        $html .= qq|<a style="cursor: pointer; cursor: hand;" onclick="show('| . $total_count . qq|')">(<span id="span| . $total_count . qq|">+</span>)</a>&nbsp;&nbsp;|;
        $html .= qq|<a name="ref| . $total_count . qq|"></a>[$total_count] <a href="$result->{url}" target="_blank">Execute</a> - | . $result->{'testname'} . ": ";
        $html .= $result->{'status'} ? qq|<font color="009900"><b>PASSED</b></font>| : qq|<font color="FF0000"><b>FAILED</b></font>|;
        $html .= "</td></tr>\n";
        $html .= qq|<tr id="| . $total_count . qq|" class="hide"><td>| . "\n";
        $html .= qq|<table border="0">| . "\n";

        # Print Request/Response
        $html .= $total_count%2 == 0? "<tr bgcolor=\"CCCCFF\">\n" : "<tr bgcolor=\"DDDDDD\">\n";
        $html .= qq|<td width="20"></td><td><a style="cursor: pointer; cursor: hand;" onclick="show('| . $total_count . qq|-| . $sub_count . qq|')">(<span id="span| . $total_count . qq|-| . $sub_count . qq|">+</a>)&nbsp;&nbsp;[| . $total_count . qq|][| . $sub_count . qq|] Request/Response Details|;
        $html .= "</td></tr>\n";
        $html .= $total_count%2 == 0? "<tr bgcolor=\"CCCCFF\" " : "<tr bgcolor=\"DDDDDD\" ";
        $html .= qq|id="| . $total_count . qq|-| . $sub_count . qq|" class="hide"><td width="20"></td><td>| . "\n";
        $html .=  "Execution Time: " . $result->{'exec_time'} . " seconds<br><br>\n";
        $html .= qq|<b>Request</b><br>| . "\n";
        $html .= qq|<textarea cols="100" rows="20">| . $result->{'response'}->request->as_string . "</textarea><br>\n";
	
	if (($self->{disable_response} == 0) and (not defined $result->{disable_response})) {
	    $html .= qq|<b>Response</b><br>| . "\n";
	    $html .= qq|<textarea cols="100" rows="20">| . $result->{'response'}->as_string . "</textarea>\n";
	}
	
        $html .= "</td></tr>\n";
        $sub_count++;

        # Print validation results
        foreach my $validation (@{$result->{'validation'}}) {
            $html .= $total_count%2 == 0? "<tr bgcolor=\"CCCCFF\">\n" : "<tr bgcolor=\"DDDDDD\">\n";
            $html .= qq|<td width="20"></td><td><a style="cursor: pointer; cursor: hand;" onclick="show('| . $total_count . qq|-| . $sub_count . qq|')">(<span id="span| . $total_count . qq|-| . $sub_count . qq|">+</a>)&nbsp;&nbsp;[| . $total_count . qq|][| . $sub_count . qq|] | . $validation->{'description'} . ": ";
            $html .= $validation->{'status'} ? qq|<font color="009900"><b>PASSED</b></font>| : qq|<font color="FF0000"><b>FAILED</b></font>|;
            $html .= "</td></tr>\n";

            $html .= $total_count%2 == 0? "<tr bgcolor=\"CCCCFF\" " : "<tr bgcolor=\"DDDDDD\" ";
            $html .= qq|id="| . $total_count . qq|-| . $sub_count . qq|" class="hide"><td width="20"></td><td><pre>| . "\n";
            $html .= "Looking for " . encode_entities($validation->{'validation_value'}) . " in response " . $validation->{'validation_key'}->{'type'} . " " . $validation->{'validation_key'}->{'name'} . "\n";
            $html .= "</pre></td></tr>\n";

            $sub_count++;
        }

        $html .= qq|</table>| . "\n";
        $html .= qq|</td></tr>| . "\n";
    }
    $html .= qq|</table><br>[<a href="#top">Back to Top</a>]| . "\n";
    #=====================#
    # Test execution ends #
    #=====================#

    $html .= "</body></html>\n";
    
    return $html;
}

1;

__END__
