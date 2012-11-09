=begin NaturalDocs
 
    This is a lightweight WebServices Request. It uses standard LWP libraries
    to make the request but extrapolates out unnecessary language and library
    semantics so that you can focus more on testing.
 
=cut

package QA::Test::WebService;

use strict;
use MIME::Base64;
use Carp qw(croak);
use Exporter 'import';
use HTML::Entities;
use HTTP::Request;
use HTTP::Request::Common;
use LWP::UserAgent;
use QA::Test::Util::Boolean qw(isTrue);
use QA::Test::Util::Time qw(startTime elapsedTime);
use XML::Simple;
use JSON::XS;
use Test::More;

=begin NaturalDocs
 
    Group: Copyright
        Copyright 2010, QA, All rights reserved.
 
    Author:
        Peter Salas
 
    Dependency:
        This library is based off of LWP::UserAgent library found in cpan. For information about LWP library, see:
        http://search.cpan.org/~gaas/libwww-perl-5.836/lib/LWP/UserAgent.pm
 
=cut

=begin NaturalDocs
 
    Group: Variables
 
    Array: @EXPORT_OK
        Allows for export of request and get_content_length subroutine to the user namespace.
 
=cut

our @EXPORT_OK = qw(
    request
    get_content_length
);

=begin NaturalDocs
 
    Group: Functions
 
    Function: request
        Executes a WebService request.
 
    Parameters:
        method - Method for the http call. Valid methods are: [GET|POST|PUT|DELETE]
        timeout - (Optional) The timeout in seconds for the request. The default value is 180 seconds.
	url - Fully qualified url of the endpoint/api, including the"http://" in it.
	basic_auth - (Optional) Does basic authentication for the request. The parameter
	    should be a STRING representing the <user>:<password> combination.
        headers - (Optional) Hash of headers to pass into the call.
	request_body - (Optional) The Request body to insert into the Web Request. If the
	    value set here represents a file, then the contents of the file are
	    posted.
        content-type - (Optional) Specifies the Content-Type of this request.
	debug - (Optional) BOOLEAN [0|1] to turn on/off the printout of the Request
	    and Response.
        
    Returns:
        An HTTP::Response object. In addition, the HTTP::Response will include 
	the following new attributes:
	
	elapsed - The elapsed time for the request in seconds.
	content_decoded - This is a HASH-ARRAY structure representing either the
	    JSON or XML that was returned. Note that this may be undef (aka null)
	    if (1) an error occured trying to convert the response content, or
	    (2) The 'Content-Type' is neither 'text/xml' or 'application/json'
        
    Example:
        (begin code)
            use QA::Test::WebService qw(request);
            
            my $response = request (
                method  => "GET",
                url     => "http://www.google.com",
                headers => { 'foo'=>'bar', 'hello'=>'world'}
            );
            
            my $code = $response->code;
            my $content = $response->content;
            my $header = $response->header('Content-Type');
            my $elapsed = $response->{elapsed};
            
            print <<EOF;
            code: $code
            Content-Type: $header
            Elapsed-Time: $elapsed
            
            ---- Body ----
            $content
            EOF
        (end)
 
=cut

sub request #(method=>'GET', timeout=>60, url=>'http://www.google.com', headers => { foo=>'bar', hello=>'world' }, request_body=>$body, 'content-type'=>'txt/html', debug => 0)
{
    my (%args) = @_;
    
    diag("Requesting: $args{'method'} $args{url}") unless isTrue($args{debug});
    my $ua = LWP::UserAgent->new(requests_redirectable => ['GET', 'HEAD', 'POST']);
    my $request = HTTP::Request->new($args{'method'}, $args{'url'});
    my $response;
    my $raw_str;
    
    ## Set the request body
    # if a reference to a file, then open, read, and set to request body
    if (defined $args{'request_body'} and -e $args{'request_body'} and -R $args{'request_body'}) {
	open FILE, "<$args{'request_body'}" or die $!;
	my @raw = <FILE>;
	close FILE;
	$raw_str = join('', @raw);
	
	$request->content($raw_str);
    } elsif (defined $args{'request_body'}) {
	$raw_str = $args{'request_body'};
	$request->content($raw_str)
    }
    
    # Basic Authentication
    $args{'headers'}->{'Authorization'} = "Basic ".encode_base64($args{'basic_auth'}) if (defined $args{'basic_auth'});
    
    # Set the headers, if any
    my $headers = $args{'headers'};
    if (defined $args{'headers'}) {
        foreach (keys %{$args{'headers'}}) {
            $request->header($_ => $headers->{$_});
        }
    }
    
    # Automatically set Content-Length of request body if not set
    if (defined $raw_str and not exists $headers->{'Content-Length'}) {
	my $byte_length = get_content_length($raw_str);
	$headers->{'Content-Length'} = $byte_length;
	$request->header('Content-Length' => $headers->{'Content-Length'});
    }

    # Set the content type, if any
    if (defined $args{'content-type'}) {
	$request->content_type($args{'content-type'});
	$headers->{'Content-Type'} = $args{'content-type'};
    }
    
    # Set the request timeout (default is 180 sec)
    my $timeout = (defined $args{timeout}) ? $args{timeout} : 180;
    $ua->timeout($timeout);
    
    ## Print Request diagnostic for DEBUG
    if (isTrue($args{debug})) {
	diag("Request:");
	diag($request->as_string);
    }

    ## Make the request
    my $start_time = startTime();
    if (defined $args{form}) {
	# Setup for multi-part form POST
	if ($headers->{'Content-Type'} eq "form-data") {
	    my $array = [];
	    
	    foreach (keys %{$args{form}})  {
		if (-e $args{form}->{$_}) {
		    push(@{$array}, $_ => [$args{form}->{$_}]);
		} else {
		    push(@{$array}, $_ => $args{form}->{$_});
		}
	    }
	    
	    $headers->{'Content'} = $array;
	}

	$response = $ua->request(POST $args{url}, %{$headers});
    } else {
	$response = $ua->request($request);
    }
    $response->{elapsed} = elapsedTime($start_time);
    
    ## Attempt to decode response content into either JSON or XML hash-array structure
    if ($response->is_success) {
	my $content_type = $response->header("Content-Type");
	if (defined $content_type and $content_type =~ m|text/xml|) {
	    eval {
		my $xml = XMLin($response->content);
		$response->{content_decoded} = $xml;
	    }
	}
	elsif (defined $content_type and $content_type =~ m|application/json|) {
	    eval {
		my $json =  decode_json($response->content);
		$response->{content_decoded} = $json;
	    }
	}
    }
    
    ## Print Response diagnostic for DEBUG
    if (isTrue($args{debug})) {
	diag("\nResponse:");
	diag($response->as_string);
    }
    
    return $response;
}

=begin NaturalDocs

    Function: get_content_length
	Returns the content-length of the string as a decimal value in Octet's.
	This is necessary to know the POST/PUT body length and appropriately
	set the 'Content-Length' header; otherwise, it can be assumed in HTTP/1.1
	that the message is chunked.
	
    Parameters:
	string - The body to POST/PUT. If this string represents a file, then the
	    file will first be opened and read.
	
    Returns:
	A decimal value representing the length of the string in Octets
	
=cut

sub get_content_length #($string)
{
    my ($string) = @_;
    croak "string is undefined at ".(caller(0))[3] unless defined $string;
    
    
    # if a reference to a file, then open, and read
    if (-e $string) {
	open FILE, "<$string" or die $!;
	my @raw = <FILE>;
	close FILE;
	$string = join('', @raw);
    }
    
    my $byte_length = 0;
    {
	use bytes;
	$byte_length = length($string);
    }
    return $byte_length;
}
