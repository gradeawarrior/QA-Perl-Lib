=begin NaturalDocs
 
    Loggically an interface that all "Test Cases" should use as a base.
 
=cut
package QA::Test::TestCase;

use strict;
use warnings;
use Carp qw(croak);
use Data::Dump qw(dump);
use Data::Dumper;
use HTTP::Request::Common;
use JSON::XS;
use LWP::UserAgent;
use QA::Test::WebService::Session;
use Statistics::Descriptive;
use Test::More;

=begin NaturalDocs
 
    Group: Copyright
        Copyright 2010, QA, All rights reserved.
 
    Author:
        Peter Salas
 
	The concept of a TestSuite follows standard xUnit pattern. For more information on xUnit,
	see the following: http://en.wikipedia.org/wiki/XUnit
	
	You should create your Test by extending <QA::Test::TestCase>
	and define your 'test' subroutines by prefixing them with 'test_'. If
	you have a setup or teardown operation, then create a 'set_up' and
	'tear_down' subroutine.
 
=cut

=begin NaturalDocs
 
    Group: Variables
 
    Member Variables:
        User defined parameters can be set. These are in addition to the user defined ones:
	
	test_subroutine - The name of the test subroutine that is currently
	    being executed.
	test_session - An instance of <QA::Test::WebService::Session>. Do note that
	    this reference only exists in the context of the test subroutine being
	    executed; in other words, this reference is only available within (1) set_up,
	    (2) method call, and (3) tear_down operation. It is not visible or in-scope
	    across test subroutines.
	sel - This variable is instantiated after first calling <get_selenium_singleton()>
	    subroutine call within your TestCase script.
 
    Constant: $VERSION
        The current version of <QA::Test::TestCase>
	
=cut

our $VERSION = 1.00;

=begin NaturalDocs
 
    Group: Constructor
 
    Function: new
        Constructor for instantiating <QA::Test::TestCase>
 
    Parameters:
        Anything you need to execute your tests
 
    Returns:
        A blessed reference of <QA::Test::TestCase>
 
=cut

sub new {
    my $class = shift;
    my $self = { @_ };
    bless($self, $class);
    
    # Setup for Webservice Testing
    $self->{test_session} = QA::Test::WebService::Session->new();
    $self->{test_session}->start();
    
    return $self;
}

=begin NaturalDocs
 
    Group: Functions
 
    Function: print_parameters
        Prints out the HASH/ARRAY structure of this instance.
 
    Parameters:
	None
 
    Returns:
        None
 
=cut

sub print_parameters #()
{
    my $self = shift;
    print dump($self), "\n";
}

=begin NaturalDocs

    Function: set_test_subroutine
	Sets the test_subroutine name. This is important if you need to know
	which test subroutine a set_up/tear_down is currently performing
	performing against. The attribute 'test_subroutine' will be
	set.
	
=cut

sub set_test_subroutine #()
{
    my ($self, $test_subroutine) = @_;
    $self->{test_subroutine} = $test_subroutine;
}

=begin NaturalDocs

    Function: get_selenium_singleton
        Singleton Constructor for <QA::Test::Web::Selenium>, which ensures that there is only one instance of Selenium.

    Parameters:
	host - The location of the selenium RC/Hub Server (e.g. 'localhost')
	port - The port that selenium RC/Hub is running on (e.g. 4444)
	browser - The browser type to execute selenium actions against (e.g. '*firefox')
	browser_url - The base URL to execute selenium actions against. This is to get around javascript security of
	    a browser which is central for selenium to work. This should be set to base URL
	    (e.g. 'http://www.google.com')
	auto_stop - (Optional) Enables auto_stop in selenium if an error occurs.
	slow_down - (Optional) - Default is 0 milliseconds. A QA feature to slowdown the tests.
	wait_time - (Optional) - Default is 30000 milliseconds. The default wait time threshold to set in the wait_for_page_to_load() operation if not specified at runtime.
	wait_threshold - (Optional) - Default is 10000 milliseconds. This is the default object wait_time threshold which is used during click and type operations. This wait_threshold is used to periodically check
	    if and when the object appears on the page if the first time fails. This is useful because occasionally the wait_for_page_to_load operation misreports
	    when the page is fully loaded.
	debug - (Optional) - Default is 0 (false). A QA feature to turn on debugging for selenium actions. This is an optional param that is by default 0 (false).
	enable_screenshot - (Optional) - Default is 0 (false). Used to automatically take a screenshot when a selenium error occurs
	screenshot_dir - (Optional) - Required if enable_screenshot is set to 1 (true). This is the root path to where the screenshot files will be written to.
	enable_network_capture - (Optional) - Default is 0 (false). Currently enables automatic call to <captureNetworkTraffic()> subroutine on every <open_ok()> and <wait_for_page_to_load_ok()> operation.

    Returns:
        A blessed reference of <QA::Test::Web::Selenium> which is saved as attribute '$self->{sel}'.
	Users should be careful with this shared resource.

=cut

sub get_selenium_singleton #(host=>'localhost', port=>'4444', browser=>'*firefox', browser_url=>'http://www.google.com', auto_stop=>1, slow_down=>0, wait_time=>60000, debug=>0, enable_screenshot=>0, screenshot_dir=>'/Users/peter/tmp', enable_network_capture=>0)
{
    my ($self, %args) = @_;
    
    ## Please ignore Selenium Singleton Referencing Logic
    $self->{sel} = ${$self->{sel_ref}};
    
    ## Instantiation of Selenium
    $self->{sel} = $self->{sel}->new_singleton(%args);
    ${$self->{sel_ref}} = $self->{sel};
    
    return $self->{sel};
}

=begin NaturalDocs

    Function: get_statistics
	Returns back common statistical information using
	Statistics::Descriptive library.
	
    Parameters:
	data - An ARRAY of data
	
    Returns:
	Returns an HASH Reference containing the following:
	
	    package - The TestCase package
	    test_sub - The test subroutine that this statistics data is
		based on.
	    count - The number of data points, which coresponds to the length of
		the data.
	    min - The minimum data point
	    max - The maximum data point
	    median - The median data point
	    mean - The average data point
	    variance - The amount of variance
	    90th - The 90th percentile
	    95th - the 95th percentile
	    99th - the 99th percentile
	    stat - A reference to Statistics::Descriptive that performed above
		calculations.
		
    Example:
	(begin code)
	my $self = shift;
	my @data = qw(1 2 3 4 5 6 7);
	
	my $stats = $self->get_statistics(@data);
	
	my $statistics = <<EOF;
	STATISTICS
	==========
	test_subroutine: $stats->{test_sub}
	data_points: $stats->{count}
	fastest_transaction: $stats->{min} sec
	longest_transaction: $stats->{max} sec
	median: $stats->{median} sec
	mean: $stats->{mean} sec
	variance: $stats->{variance} sec
	90th_percentile: $stats->{'90th'} sec
	95th_percentile: $stats->{'95th'} sec
	99th_percentile: $stats->{'90th'} sec
	EOF
	(end)
    
=cut

sub get_statistics #(@data)
{
    my ($self, @data) = @_;
    my $func_name = caller(0);
    croak "\@data is undefined at $func_name!" unless @data > 0;
    
    my $stat = Statistics::Descriptive::Full->new();
    $stat->add_data(@data);
    my $perc_90 = $stat->percentile(90);
    my $perc_95 = $stat->percentile(95);
    my $perc_99 = $stat->percentile(99);
    
    my %hash = (
	    package	=> ref($self),
	    test_sub	=> $self->{test_subroutine},
	    count	=> $stat->count(),
	    min		=> $stat->min(),
	    max		=> $stat->max(),
	    median	=> $stat->median(),
	    mean	=> $stat->mean(),
	    variance	=> $stat->variance(),
	    '90th'	=> $perc_90,
	    '95th'	=> $perc_95,
	    '99th'	=> $perc_99,
	    stat	=> $stat,
    );

    return \%hash;
}

=begin NaturalDocs

    Function: print_statistics
	Prints the statistical information to DEBUG
	
    Parameters:
	data - An ARRAY of data
	
    Returns:
        The statistic information will be printed to debug with the following
        information:
        
        (begin code)
        STATISTICS
        ==========
        test_subroutine: $test_sub
        data_points: $count
        fastest_transaction: $min sec
        longest_transaction: $max sec
        median: $median sec
        mean: $mean sec
        variance: $variance sec
        90th_percentile: $perc_90 sec
        95th_percentile: $perc_95 sec
        99th_percentile: $perc_99 sec
        (end)

=cut

sub print_statistics #(@data)
{
    my ($self, @data) = @_;
    my $func_name = caller(0);
    croak "\@data is undefined at $func_name!" unless @data > 0;
    
    
	
    my $stats = $self->get_statistics(@data);
    my $statistics = <<EOF;
STATISTICS
==========
test_package: $stats->{package}
test_subroutine: $stats->{test_sub}
data_points: $stats->{count}
fastest_transaction: $stats->{min} sec
longest_transaction: $stats->{max} sec
median: $stats->{median} sec
mean: $stats->{mean} sec
variance: $stats->{variance} sec
90th_percentile: $stats->{'90th'} sec
95th_percentile: $stats->{'95th'} sec
99th_percentile: $stats->{'99th'} sec
EOF

    diag($statistics);
}

1;
