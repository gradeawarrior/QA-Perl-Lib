=begin NaturalDocs

    This is NetworkCapture package that will parse the selenium raw xml from captureNetworkTrafficRaw() subroutine call.
    It will also parse perf log stats.

=cut

package QA::Test::Web::NetworkCapture;

use strict;
use XML::Simple;
use Data::Dumper;
use QA::Test::Util;
use Test::More;
use Carp qw(croak);
use Time::HiRes qw (sleep gettimeofday tv_interval);

=begin NaturalDocs

    Group: Copyright
	Copyright 2009, QA,  All rights reserved.

    Author:
	Pritesh Patel

    Group: Variables

=cut

=begin NaturalDocs

    Group: Constructor
    
    Function: new
    
    Parameters:
	xml - The raw xml STRING from <QA::Test::Web::Selenium::captureNetworkTrafficRaw()>. It can be error_page for pages which has errors.
	page_load_duration - Time it took to load the page.
	page_url - URL of the page. It will be used to get the perf log of the page.
	message - (Optional) If the message is provided with the page load then it will be used in the results.
	
    Return:
	A reference to QA::Test::Web::NetworkCapture

=cut


sub new #($xml)
{
    my($class, $xml, $page_load_duration, $page_url,$message) = @_;
    my $self = bless({}, $class);
    $self->{page_stats}->{page_load_duration} = $page_load_duration;
    if($xml eq 'error_page' || $xml eq 'network_capture_failed') {
	$self->set_stats_zero_PageFailure($page_url,$message);
        $self->print_perf_stats();
	#croak "xml is required when instantiating QA::Test::Web::NetworkCapture";
	return $self;
    }
    croak "xml is required when instantiating QA::Test::Web::NetworkCapture" unless defined $xml;
    
    # replace OK, with nothing
    $xml =~ s/OK,//;
    $self->{xml} = new XML::Simple (KeyAttr=>[]);
    
    # replace & with &amp
    $xml =~ s/&/&amp;/g;
    $self->{raw_xml} = $self->{xml}->XMLin($xml);
    
    $self->{raw_xml}->{entry} = QA::Test::Util->returnArray($self->{raw_xml}->{entry});
    
    # Pre-populate page statistics
    $self->get_num_requests();
    $self->get_content_size();
    $self->get_http_status_codes();
    $self->get_file_extension_stats();
    $self->get_perflog_stats($page_url,$message);
    
    # Printing out performance stats
    $self->print_perf_stats();
    
    return $self;
}

=begin NaturalDocs

    Group: Functions

    Function: set_stats_zero_PageFailure
	Gets the raw perflog information.
	
    Parameters:
	page_url_full - url of the page which will be used to get perf log
	message - message which was provided with page load
	
    Return:
	None

=cut

sub set_stats_zero_PageFailure #()
{
    my ($self,$page_url_full,$message) = @_;
    
    # Splitting the url with '?' to remove any parammeters
    my @temp = split(/\?/, $page_url_full);
    my $page_url = $temp[0];
    $page_url_full =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;

    $page_url_full =~ s/&/&amp;/g;
    $self->{page_stats}->{page_url} = $page_url_full;
    $self->{page_stats}->{page_message} = $message if $message;
    
    $self->{page_stats}->{total_request_count} = 0;
    $self->{page_stats}->{total_kbytes} = 0;
    $self->{page_stats}->{page_load_duration} = 0;
    
    $self->{page_stats}->{status_code_count}->{error_page} = 0;
    $self->{page_stats}->{file_extensions}->{error_page}->{count} = 0;
    $self->{page_stats}->{file_extensions}->{error_page}->{size} = 0;   
}


=begin NaturalDocs

    Function: get_perflog_stats
	Gets the raw perflog information.
	
    Parameters:
	page_url_full - url of the page which will be used to get perf log
	message - message provided during the page load from the test script
	
    Return:
	None

=cut

sub get_perflog_stats #()
{
    my ($self,$page_url_full,$message) = @_;
    my $debug = 0;
    # Splitting the url with '?' to remove any parammeters
    diag("\n\n===============================================") if $debug;
    diag("The one that gets passed : " . $page_url_full) if $debug;
    diag("----------------------------------------------------") if $debug;
    my @temp = split(/\?/, $page_url_full);
    my $page_url = $temp[0];
    diag("Page URL after the split with ? : " . $page_url) if $debug;
    diag("----------------------------------------------------") if $debug;

    $page_url_full =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
    diag("Page URL after Decoding : " . $page_url_full) if $debug;
    diag("----------------------------------------------------") if $debug;
    
    $page_url_full =~ s/&/&amp;/g;
    diag("Page URL after Replacing & : " . $page_url_full) if $debug;
    diag("----------------------------------------------------") if $debug;
    
    # save page url and page message
    $self->{page_stats}->{page_url} = $page_url_full;
    $self->{page_stats}->{page_message} = $message if $message;

    diag("Page URL after in hash : " . $self->{page_stats}->{page_url}) if $debug;
    diag("======================================================") if $debug;
}

=begin NaturalDocs

    Function: get_num_requests
	Retrieves the number of requests for a page

    Return:
	total_request_count - The number of requests

=cut

sub get_num_requests #()
{
    my $self = shift;
    $self->{page_stats}->{total_request_count} = @{$self->{raw_xml}->{entry}} ;
    return $self->{page_stats}->{total_request_count};
}

=begin NaturalDocs

    Function: get_content_size
	Retrieves total kb passed through proxy

    Return:
	total_kbytes - total kb

=cut

sub get_content_size #()
{
    my $self = shift;
    $self->{page_stats}->{total_kbytes} = 0;
    my $i = @{$self->{raw_xml}->{entry}};
    while ($i >= 0) {
	$self->{page_stats}->{total_kbytes} += $self->{raw_xml}->{entry}->[$i]->{bytes} if defined $self->{raw_xml}->{entry}->[$i]->{bytes};
	$i--;
    }
    $self->{page_stats}->{total_kbytes} = $self->{page_stats}->{total_kbytes} / 1000.0;
    return $self->{page_stats}->{total_kbytes};
}
 
=begin NaturalDocs

    Function: get_http_status_codes
	Shows counts of each status http response.

    Return:
	status_code_count - an array reference to all the status codes encountered and their count

=cut

sub get_http_status_codes #()
{
    my $self = shift;
    my $i = @{$self->{raw_xml}->{entry}};
    while ($i >= 0) {
	$self->{page_stats}->{status_code_count}->{$self->{raw_xml}->{entry}->[$i]->{statusCode}} += 1 if defined $self->{raw_xml}->{entry}->[$i]->{statusCode};
	$i--;
    }
    return $self->{page_stats}->{status_code_count};
}

=begin NaturalDocs

    Function: get_file_extension_stats
	Shows counts and total size of each file type on the page

    Return:
	file_extensions - an array reference to all the file extension counts and their total size in kb

=cut

sub get_file_extension_stats #()
{
    my $self = shift;
    my $extension = 0;
    my $size = 0;
    my $url = '';
    my @temp = 0;
    my @temp2 = 0;
    my $i = @{($self->{raw_xml}->{entry})};
    while ($i >= 0) {
	    $url = $self->{raw_xml}->{entry}->[$i]->{url} if defined $self->{raw_xml}->{entry}->[$i]->{url} . "?"; # making sure we have one ? for split
    	    if($url) {
	        $size = $self->{raw_xml}->{entry}->[$i]->{bytes} / 1000.0 if defined $self->{raw_xml}->{entry}->[$i]->{bytes};
	        @temp = split(/\?/, $url); # split the array by ?
	        @temp2 = split(/\//,$temp[0]); # split the first element of array by /
	        if($temp2[$#temp2] =~ /\./) { # if dot(.) exists in the last element generally its name of the file
		    @temp2 = split(/\./,$temp2[$#temp2]); # splitting up the file name by . so that we can get the extension
		    $extension = pop @temp2; # getting the extension
		} elsif ($temp2[$#temp2] == 'css') { # most of the css required special processing
		    $extension = 'css';
		} else {
		    $extension = 'unknown';
		}
		$self->{page_stats}->{file_extensions}->{$extension}->{count} += 1;
		$self->{page_stats}->{file_extensions}->{$extension}->{size} += $size;
	}
	$i--;
    }
    return $self->{page_stats}->{file_extensions};
}   

=begin NaturalDocs

    Function: get_network_times
	Shows counts and total size of each file type on the page

    Return:
	file_extensions - an array reference to all the file extension counts and their total size in kb

=cut

sub get_network_times #()
{
    my $self = shift;
    my $extension = 0;
    my $size = 0;
    my $url = '';
    my @start_times = 0;
    my @end_times = 0;
    my $no_of_requests = $self->{page_stats}->{total_request_count};
    my $i = 0;
    while ($i < $no_of_requests) {
	if(!$self->{raw_xml}->{entry}) { next; }
	    $start_times[$i] = $self->{raw_xml}->{entry}->[$i]->{start};
	    $end_times[$i] = $self->{raw_xml}->{entry}->[$i]->{start};
	    $i++;
    }
    $i=0;
    @start_times = sort @start_times;
    @end_times = sort @end_times;
    while ($i < $no_of_requests) {
        print "\n Request $i ==> start Time : $start_times[$i] , end time : $end_times[$i]";
	$i++;
    }
}

=begin NaturalDocs

    Function: print_perf_stats
	Prints out all the stats captured previously

    Return:
	None

=cut

sub print_perf_stats #()
{
    my $self = shift;

    diag("==============================================================\n");
    diag("Page URL: " . $self->{page_stats}->{page_url} );
    diag("Page Message: " . $self->{page_stats}->{page_message} );
    diag("------------------------------------------------------------\n");
    diag("Total Http Requests : " . $self->{page_stats}->{total_request_count} );
    diag("------------------------------------------------------------\n");
    diag("Total KBytes Recieved: " . $self->{page_stats}->{total_kbytes} . "Kbytes");
    diag("------------------------------------------------------------\n");
    for my $key (sort keys %{$self->{page_stats}->{status_code_count}}) {
        diag("Response Code is : " . $key . " == Count : " . $self->{page_stats}->{status_code_count}->{$key});
    }
    diag("------------------------------------------------------------\n");
    for my $key2 (sort keys %{$self->{page_stats}->{file_extensions}}) {
	diag("File extension is : " . $key2 . "  ==> Count : " . $self->{page_stats}->{file_extensions}->{$key2}->{count} . "  Size : " . $self->{page_stats}->{file_extensions}->{$key2}->{size} ."kb");
    }
    diag("------------------------------------------------------------\n");
    diag("Page Load Time : " . $self->{page_stats}->{page_load_duration} . " seconds");
    diag("==============================================================\n");
}
return 1;
