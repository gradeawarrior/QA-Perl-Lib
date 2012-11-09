=begin NaturalDocs

    This module is a QA enhanced Selenium module based on WWW::Selenium perl libraries and extends Test::WWW::Selenium.
    It takes everything that can be done using Selenium out-of-the-box, and enhances to support the following:
    
	- AJAX applications and dynamic content
	- QA error page detection
	- Page statistics (e.g. page size, status codes)
	
    For more information about Selenium and related operations, see CPAN: <http://search.cpan.org/~lukec/Test-WWW-Selenium-1.21/lib/WWW/Selenium.pm>

=cut

package QA::Test::Web::Selenium;

use strict;
use base qw(Test::WWW::Selenium);
use HTML::TreeBuilder;
use HTTP::Request::Common qw(GET);
use QA::Test::Util;
use QA::Test::Web::NetworkCapture;
use Test::More;
use Time::HiRes qw (sleep gettimeofday tv_interval);
use Carp qw(croak);

=begin NaturalDocs

    Group: Copyright
	Copyright 2010, QA, All rights reserved.

    Author:
	Peter Salas

	For Selenium commands, see page: <http://search.cpan.org/~lukec/Test-WWW-Selenium-1.21/lib/WWW/Selenium.pm>
	
=cut

=begin NaturalDocs

    Group: Synopsis
    
    (begin code)
    use strict;
    use QA::Test::Web::Selenium;
    use Test::More qw(no_plan);
    
    my $host = 'localhost';
    my $port = '4444';
    my $browser_type = '*firefox';
    my $domain = 'google.com';
    my $url = 'http://www.' . $domain;
    my $auto_stop = 1;
    my $slow_down = 1000;              # Slow down in milliseconds (default 33 milliseconds)
    my $debug = 0;                     # boolean to turn on/off debugging output (default off)
    my $capture_network_traffic = 1;   # boolean to capture network traffic (like doing firebug on browser)

    my $sel = QA::Test::Web::Selenium->new(
		host => $host,
		port => $port,
		browser => $browser_type,
		browser_url => $url,
		auto_stop => $auto_stop,
		slow_down => $slow_down,
		debug => $debug,
		enable_network_capture => $capture_network_traffic
    );

    # Start the selenium browser
    $sel->start();

    # Go to WWW
    $sel->open_ok($url);
    
    my $xpath = qq|name=q|;
    $sel->type_ok($xpath, "Hello World");
    $sel->click_ok("name=btnG");
    print "title: ".$sel->get_title, "\n";
    
    $sel->stop();
    (end)

=cut

=begin NaturalDocs

    Group: Variables
    
    Member Variables:
	slow_down - Slow down in seconds. If this is not set, then it can be assumed to be 0 seconds.
	debug - debug value. If this is not set, then it can be assumed to be 0 (false).
	domain - The domain in which tests are being executed on. This is essentially the domain passed in from $sel->{browser_url}.
	wait_time - This is the default wait_time threshold which is set if the user does not specify a wait_time in the wait_for_page_to_load operation.
	wait_threshold - This is the default object wait_time threshold which is used during click and type operations. This wait_threshold is used to periodically check
	    if and when the object appears on the page if the first time fails. This is useful because occasionally the wait_for_page_to_load operation misreports
	    when the page is fully loaded.
	enable_screenshot - Used to automatically take a screenshot when a selenium error occurs
	screenshot_dir - This is the root path to where the screenshot files will be written to.
	enable_network_capture - BOOLEAN that enables automatic call to <captureNetworkTraffic()> subroutine on every <open_ok()> and <wait_for_page_to_load_ok()> operation.

=cut

eval 'require Encode';
my $encode_present = !$@;
Encode->import('decode_utf8') if $encode_present;
my $session;

=begin NaturalDocs

    Group: Constructor

    Function: new
        Constructor for <QA::Test::Web::Selenium>, which is the same as CPAN's WWW::Selenium with extra optional parameters.

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
        A blessed reference of <QA::Test::Web::Selenium>. This is typically saved as a variable '$sel'.

=cut

sub new #(host=>'localhost', port=>'4444', browser=>'*firefox', browser_url=>'http://www.google.com', auto_stop=>1, slow_down=>0, wait_time=>60000, debug=>0, enable_screenshot=>0, screenshot_dir=>'/Users/peter/tmp', enable_network_capture=>0)
{
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    
    $self->set_slowdown($args{slow_down}) unless not defined $args{slow_down};
    $self->set_wait_time($args{wait_time});
    $self->set_object_wait_threshold($args{wait_threshold});
    $self->enable_debug() unless not QA::Test::Util->isTrue($args{debug});
    
    # Screenshot Reporting
    $self->{enable_screenshot} = QA::Test::Util->isTrue($args{enable_screenshot});
    $self->{enable_screenshot} = 0 unless defined $self->{enable_screenshot};
    $self->{screenshot_dir} = $args{screenshot_dir};
    croak 'screenshot_dir was not defined when enable_screenshot set to true!' unless not QA::Test::Util->isTrue($self->{enable_screenshot}) or defined $self->{screenshot_dir};
    croak qq|screenshot_dir '$self->{screenshot_dir}' is not a valid path!| unless not defined $self->{screenshot_dir} or -e $self->{screenshot_dir};
    
    # Set Capture Network Traffic
    $self->{enable_network_capture} = QA::Test::Util->isTrue($args{enable_network_capture});
    
    # Set domain
    $self->{domain} = $args{browser_url};
    $self->{domain} =~ s/http:\/\/[a-zA-Z0-9]+\.(.*)/$1/;
    
    $self->start();
    return $self;
}

=begin NaturalDocs

    Function: new_singleton
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
        A blessed reference of <QA::Test::Web::Selenium>. This is typically saved as a variable '$sel'.

=cut

sub new_singleton #(host=>'localhost', port=>'4444', browser=>'*firefox', browser_url=>'http://www.google.com', auto_stop=>1, slow_down=>0, wait_time=>60000, debug=>0, enable_screenshot=>0, screenshot_dir=>'/Users/peter/tmp', enable_network_capture=>0)
{
    my ($class, %args) = @_;
    $session ||= $class->new(%args);
    return $session;
}

=begin NaturalDocs

    Group: New Operations
    
    Function: set_slowdown
	Sets the 'slow_down' in milliseconds to sleep before a major operation. Currently, this will sleep for the following.
	    - <click_ok()>
	    - <click_at_ok()>
	    - <select_ok()>
	    - <type_ok()>
    
    Parameters:
	slow_down - The number of in milliseconds to slow down Selenium actions
	
    Returns:
	None

=cut

sub set_slowdown #($slow_down)
{
    my $self = shift;
    my $slow_down = shift;
    
    croak qq|slow_down not defined!| unless defined $slow_down;
    $self->{slow_down} = $slow_down;
}

=begin NaturalDocs

    Function: set_wait_time
	Sets the default wait_time threshold in milliseconds used in the wait_for_page_to_load operation. This variable
	is not used if the user specifies a wait_time in the wait_for_page_to_load operation, otherwise, this is set.
	
    Parameters:
	wait_time - (Optional) - Default is 30000 milliseconds (30 sec). This is the threshold for <wait_for_page_to_load_ok()> operations before timing out.
	
    Returns:
	None

=cut

sub set_wait_time #($wait_time)
{
    my $self = shift;
    my $wait_time = shift;
    
    $wait_time = 30000 unless defined $wait_time;
    $self->{wait_time} = $wait_time;
}

=begin NaturalDocs

    Function: set_object_wait_threshold
	Sets the default object wait threshold in milliseconds used when attempting to click or type on an object that should exist on the page.
	An object may not exist (and visible) occasionally when a wait_for_page_to_load incorrectly reports a page has finished loading.
	
    Parameters:
	wait_threshold - (Optional) - Default is 10000 milliseconds (10 sec)
	
    Returns:
	None
    
=cut

sub set_object_wait_threshold #($wait_threshold)
{
    my $self = shift;
    my $wait_threshold = shift;
    
    $wait_threshold = 10000 unless defined $wait_threshold;
    $self->{wait_threshold} = $wait_threshold/1000;
}

#==========#

=begin NaturalDocs

    Function: exec_slowdown
	Executes the slow down operation with specified sleep time
	
    Parameters:
	None
	
    Returns:
	None
    
=cut

sub exec_slowdown #()
{
    my $self = shift;
    
    $self->{slow_down} = 0 unless defined $self->{slow_down};
    diag(qq|Sleeping for $self->{slow_down} milliseconds!|) unless not defined $self->{debug} or $self->{debug} == 0;
    sleep $self->{slow_down}/1000;
}

=begin NaturalDocs

    Function: enable_debug
	Enables debug = 1 (true)
	
    Parameters:
	None
	
    Returns:
	None
	
=cut

sub enable_debug #()
{
    my $self = shift;
    $self->{debug} = 1;
    $self->{verbose} = 1;
}

=begin NaturalDocs

    Function open_func
	This is a placeholder for any operation that needs to be executed before a
	selenium action. This is similar to a setup function. This method is typically used
	within the L<QA::Test::Web::Selenium> object.
	
    Parameters:
	None
	
    Returns:
	None
	
=cut

sub open_func #()
{
    my $self = shift;
    $self->exec_slowdown();
}

=begin NaturalDocs

    Function: capture_entire_page_screenshot_ok
	Saves the entire contents of the current window canvas to a PNG file.Contrast this
	with the captureScreenshot command, which captures thecontents of the OS viewport (i.e.
	whatever is currently being displayed on the monitor), and is implemented in the RC only.
	Currently this onlyworks in Firefox when running in chrome mode, and in IE non-HTA using
	the EXPERIMENTAL "Snapsie" utility. The Firefox implementation is mostly
	borrowed from the Screengrab! Firefox extension. Please see <http://www.screengrab.org> and
	<http://snapsie.sourceforge.net/> fordetails.

	In addition, if the $sel->{screenshot_dir} attribute was set, then the $filename is optional.
	It will write to disk using the 'screenshot_dir' as the base path and filename tagged with the
	timestamp YYMMDDYYhhmmss.png
	
    Parameters:
	filename - the path to the file to persist the screenshot as. No filename extension will be appended by default.
	    Directories will not be created if they do not exist, and an exception will be thrown, possibly by native code.
	kwargs - a kwargs string that modifies the way the screenshot is captured.
	    
	    Example: "background=#CCFFDD" . Currently valid options: =item background
	    
	    the background CSS for the HTML document. This may be useful to set for capturing screenshots of less-than-ideal layouts, for example where absolute positioning causes the calculation of the canvas dimension to fail and a black background is exposed (possibly obscuring black text).
	    
    Returns:
	1 (true) if successful. 0 (false) otehrwise

=cut

sub capture_entire_page_screenshot_ok #()
{
    my ($self, $filename, $kwargs) = @_;
    
    croak 'filename was not defined!' unless defined $filename or defined $self->{screenshot_dir};
    $filename = $self->{screenshot_dir}."/".QA::Test::Util::Time->getTime_YYMMDDhhmmss().".png" unless defined $filename;
    
    return 0 unless $self->SUPER::capture_entire_page_screenshot_ok($filename, $kwargs);
    diag(qq|<a href="$filename"><img src="$filename"/></a>|);
    return 1;
}

=begin NaturalDocs

    Function: get_browser_name
	Returns the browser name returned by the following javascript.
	
	(begin code)
	window.navigator.appName
	(end)
	
	*Example Output:* Netscape
	
    Parameters:
	None
	
    Returns:
	The output from calling window.navigator.appName
	
=cut

sub get_browser_name #()
{
    my $self = shift;
    return $self->get_eval("window.navigator.appName");
}

=begin NaturalDocs

    Function: get_browser_version
	Returns the browser version and Operating System returned by the following javascript.
	
	(begin code)
	window.navigator.appVersion
	(end)
	
	*Example Output:* 5.0 (Macintosh; en-US)
	
    Parameters:
	None
	
    Returns:
	The output from calling window. navigator.appVersion
	
=cut

sub get_browser_version #()
{
    my $self = shift;
    return $self->get_eval("window.navigator.appVersion");
}

=begin NaturalDocs

    Function: verify_no_page_error
	Verifies whether the current page has an error. In addition, if an error occurs, then a failure is generated.
	
    Paramters:
	None
	
    Returns:
	Returns 1 (true) if there are no page errors. 0 (false) if there is a page error.

=cut

sub verify_no_page_error {
    my $self = shift;
    
    # Verify page
    my $page_title = $self->get_title();
    my $yikes_page = $page_title =~ m/Yikes/;
    my $page_not_found = $page_title =~ m/Page Not Found/;
    my $page_not_exist = $page_title =~ m/doesn't exist/i;
    my $fatal_error = $self->get_text("//body") =~ m/Fatal\s+error/i;
    
    # Log Failures
    fail("'Yikes!' error on '".$self->get_location()."'") unless not $yikes_page;
    fail("'Page Not Found' error on '".$self->get_location()."'") unless not $page_not_found;
    fail("'Page Doesnt Exist' error on '".$self->get_location()."'") unless not $page_not_exist;
    fail("'Fatal error on '".$self->get_location()."'\n".$self->get_text("//body")) unless not $fatal_error;
    
    my $result = (not $yikes_page and not $page_not_found and not $page_not_exist and not $fatal_error);
    diag("Page Error Result: $result") if $self->{debug};
    
    return (not $yikes_page and not $page_not_found and not $page_not_exist and not $fatal_error);
}
    
=begin NaturalDocs

    Group: Enhanced Selenium Operations

    Function: open_ok
	This is an overiding method for open_ok. Opens a URL in the test frame.
	This accepts both relative and absoluteURLs.The "open" command waits for the page
	to load before proceeding,ie. the "AndWait" suffix is implicit.Note: The URL must
	be on the same domain as the runner HTMLdue to security restrictions in the browser
	(Same Origin Policy). If youneed to open an URL on another domain, use the Selenium
	Server to start anew browser session on that domain.
	
    Parameters:
	url - STRING representing the url to open a Selenium session to.
	
    Returns:
	1 (true) if successful. 0 (false) otherwise
    
=cut

sub open_ok #('http://www.google.com')
{
    my $self = shift;
    my $pass_fail = 1;
    my $success = 0;

    # Calculating the page load time
    my $page_start_time = [gettimeofday];
    $success = $self->SUPER::open_ok(@_);
    my $page_load_duration = tv_interval($page_start_time);
    
    # Verify if no page error
    $success = ($success and $self->verify_no_page_error());
    
    # Getting the page url to be used in NetworkCapture package
    my $page_url = $self->get_location();
    
    # If perf stats is enabled from config then this will capture the performance stats.For error pages we would set perf stats to 0.
    # by sending 1 as the last argument we are saying that this is an error page
    diag((caller(0))[3]." success: ".$success) if $self->{debug};
    $self->captureNetworkTraffic(page_load_duration=>$page_load_duration, page_url=>$page_url, is_err_page=>(not $success)) if $self->{enable_network_capture};
    
    return $success;
}

=begin NaturalDocs

    Function: click_ok
	This is an overiding method for click_ok. It performs the same operation defined
	in Test::WWW::Selenium but in addition executes <open_func()>.
	
    Parameters:
	object locator - The object identifier (e.g. xpath)
	message - (Optional) The debug message to print when clicking the object
	
    Returns:
	1 (true) if successful. 0 (false) otherwise
	
=cut

sub click_ok #('//body/a[1]', "Clicking first link on page")
{
    my $self = shift;
    
    $self->open_func();
    return 0 unless $self->is_present_and_visible_condition($_[0],0);
    return $self->SUPER::click_ok(@_);
}

=begin NaturalDocs

    Function: click_and_wait_ok
	This is the equivalent of calling <click_ok()> and <wait_for_page_to_load_ok()>.
	The default wait_time threshold is used for the <wait_for_page_to_load_ok()> call.
	
    Parameters:
	object locator - The object identifier (e.g. xpath)
	message - (Optional) The debug message to print when clicking the object
	
    Returns:
	1 (true) if successful. 0 (false) otherwise
	
=cut

sub click_and_wait_ok #('//body/a[1]', "Clicking first link on page")
{
    my ($self,@args) = @_;
    
    return 0 unless $self->click_ok(@args);
    return $self->wait_for_page_to_load_ok($self->{wait_time},$args[1]);
}

=begin NaturalDocs

    Function: click_at_ok
	This is an overiding method for click_at_ok. It performs the same operation defined
	in Test::WWW::Selenium but in addition executes <open_func()>.
	
    Parameters:
	object locator - The object identifier (e.g. xpath)
	coord_string - (Optional) specifies the x,y position (i.e. - 10,20) of the mouse event relative to the element returned by the locator.
	
    Returns:
	1 (true) if successful. 0 (false) otherwise
	
=cut

sub click_at_ok #('//body/h1/a')
{
    my $self = shift;
    
    $self->open_func();
    return 0 unless $self->is_present_and_visible_condition($_[0],1);;
    return $self->SUPER::click_at_ok(@_);
}

=begin NaturalDocs

    Function: type_ok
	This is an overiding method for type_ok. It performs the same operation defined
	in Test::WWW::Selenium but in addition executes <open_func()>.
	
    Parameters:
	locator - is an element locator
	value - is the value to type
	
    Returns:
	1 (true) if successful. 0 (false) otherwise
	
=cut

sub type_ok #('id=textfield1', "My Text")
{
    my $self = shift;
    
    $self->open_func();
    return 0 unless $self->is_present_and_visible_condition($_[0],1);;
    return $self->SUPER::type_ok(@_);
}

=begin NaturalDocs

    Function: type_keys_ok
	Simulates keystroke events on the specified element, as though you typed the
	value key-by-key. This is a convenience method for calling keyDown, keyUp, keyPress
	for every character in the specified string;this is useful for dynamic UI widgets
	(like auto-completing combo boxes) that require explicit key events.

	Unlike the simple "type" command, which forces the specified value into the page directly,
	this commandmay or may not have any visible effect, even in cases where typing keys would
	normally have a visible effect.For example, if you use "typeKeys" on a form element, you
	may or may not see the results of what you typed inthe field.

	In some cases, you may need to use the simple "type" command to set the value of the
	field and then the "typeKeys" command tosend the keystroke events corresponding to what you just typed.

    Parameters:
	locator - is an element locator
	value - is the value to type
	
    Returns:
	1 (true) if successful. 0 (false) otherwise

=cut

sub type_keys_ok #('id=textfield1', "My Text")
{
    my $self = shift;
    return 0 unless $self->is_present_and_visible_condition($_[0],1);;
    return $self->SUPER::type_keys_ok(@_);
}

=begin NaturalDocs

    Function: check_ok
	Checks a toggle-button (checkbox/radio)
    
    Parameters:
	locator - is an element locator
	
    Returns:
	1 (true) if successful. 0 (false) otherwise
	
=cut

sub check_ok #('id=checkbox')
{
    my $self = shift;
    return 0 unless $self->is_present_and_visible_condition($_[0],1);;
    return $self->SUPER::check_ok(@_);
}

=begin NaturalDocs

    Function: uncheck_ok
	Uncheck a toggle-button (checkbox/radio)
	
    Parameters:
	locator - is an element locator
	
    Returns:
	1 (true) if successful. 0 (false) otherwise
	
=cut

sub uncheck_ok #('id=checkbox')
{
    my $self = shift;
    return 0 unless $self->is_present_and_visible_condition($_[0],1);;
    return $self->SUPER::uncheck_ok(@_);
}

=begin NaturalDocs

    Function: select_ok
	This is an overiding method for select_ok. It performs the same operation defined
	in Test::WWW::Selenium but in addition executes <open_func()>.
	
	Select an option from a drop-down using an option locator. Option locators provide
	different ways of specifying options of an HTMLSelect element (e.g. for selecting a
	specific option, or for assertingthat the selected option satisfies a specification).
	
    Parameters:
	locator - is an element locator
	option - an option locator (a label by default)
	
    Returns:
	1 (true) if successful. 0 (false) otherwise
	
=cut

sub select_ok #('id=dropdown1', 'label=Europe')
{
    my $self = shift;
    
    $self->open_func();
    return 0 unless $self->is_present_and_visible_condition($_[0],1);;
    return $self->SUPER::select_ok(@_);
}

=begin NaturalDocs

    Function: go_back_and_wait_ok
	Simulates the user clicking the "back" button on their browser and waits for page to load.
	The default wait_time threshold is used for the <wait_for_page_to_load_ok()> call.
	
    Parameters:
	None
	
    Returns:
	1 (true) if successful. 0 (false) otherwise
	
=cut

sub go_back_and_wait_ok {
    my $self = shift;
    
    return 0 unless $self->SUPER::go_back_ok(@_);
    return $self->wait_for_page_to_load_ok();
}

=begin NaturalDocs

    Function: wait_for_page_to_load_ok
	This is an overiding method for wait_for_page_to_load_ok. It performs the same operation defined
	in Test::WWW::Selenium but in addition checks the following.
	
	- Did not get Ykes page
	- Did not get Page Not Found error
	- Page doesn't exist error
	- 'Fatal error' in the body
	
    Parameters:
	wait_time - (Optional) - Default is the wait_time specified in <set_wait_time()>
	message - (Optional) Default is no message
	
    Returns:
	1 (true) if successful. 0 (false) otherwise

=cut

sub wait_for_page_to_load_ok #($wait_time)
{
    my ($self, $wait_time,$message) = @_;
    
    # Execute Wait for Page Load
    $wait_time = $self->{wait_time} unless defined $wait_time;

    # Captures the page load time 
    my $page_start_time = [gettimeofday];
    my $return_val = $self->SUPER::wait_for_page_to_load_ok($wait_time);    
    my $page_load_duration = tv_interval($page_start_time);
    
    # Verify if there are page errors
    my $result = ($return_val and $self->verify_no_page_error());
    
    # Gets the page url which will be used in NetworkCapture package
    my $page_url = $self->get_location();
    
    # Capture Network Traffic no matter what the page is. For error pages we would like to set perf stats to 0
    # by sending 1 as the last argument we are saying that this is an error page
    diag((caller(0))[3]." result: ".$result) if $self->{debug};
    $self->captureNetworkTraffic(page_load_duration=>$page_load_duration, page_url=>$page_url, is_err_page=>(not $result)) if $self->{enable_network_capture};
    
    # Capture Screenshot
    $self->capture_entire_page_screenshot_ok() unless $result or not QA::Test::Util->isTrue($self->{enable_screenshot});
    
    return $result;
}

=begin NaturalDocs

    Function: is_present_and_visible
	Verifies that the specified element is somewhere on the page. This includes checking both
	is_element_present() and is_visible().
    
    Parameters:
	locator - The html object locator
	check_visibility - (Optional) - Default is 1 (true). A switch to only check whether the element is present.
	    It will skip the check for is_visible if set to 0 (false).
	    
    Returns:
	1 (true) if exists. 0 (false) otherwise
	
=cut

sub is_present_and_visible #($locator, $check_visibility)
{
    my ($self, $locator, $check_visibility) = @_;
    croak "locator is undefined!" unless defined $locator;
    $check_visibility = QA::Test::Util->isTrue($check_visibility);
    
    # Check if Present and Visible
    my $present = 0;
    my $visible = 0;
    $present = $self->SUPER::is_element_present($locator);
    $visible = $self->SUPER::is_visible($locator) unless not $present;
    
    # Print Diagnostic messages and return 1 (true) or 0 (false)
    diag("$locator is not present on page") unless $present;
    diag("$locator is present on page") unless not QA::Test::Util->isTrue($self->{debug});
    return 0 unless $present;
    return 1 unless $check_visibility;
    diag("$locator is not visible on page") unless $visible;
    diag("$locator is visible on page") unless not QA::Test::Util->isTrue($self->{debug});
    return $visible;
}

=begin NaturalDocs

    Function: is_present_and_visible_condition
	An enhanced <is_present_and_visible()> check, but if the object is not found, it will continue
	to check if the object is present after an incrementing amount of milliseconds passes. If the object is not found after
	$wait_threshold attribute (default is 10000 milliseconds - 10 seconds), then the method return 0 (false). The
	$wait_threshold can be set in <set_object_wait_threshold()> subroutine.
	
    Parameters:
	locator - The html object locator
	check_visibility - (Optional) - Default is 1 (true). A switch to only check whether the element is present.
	    It will skip the check for is_visible if set to 0 (false).
	    
    Returns:
	1 (true) if exists. 0 (false) otherwise
    
=cut

sub is_present_and_visible_condition #($locator, $check_visibility)
{
    my ($self, $locator, $check_visibility) = @_;
    
    $check_visibility = 1 unless defined $check_visibility;
    my $t0 = [gettimeofday];
    my $duration = 0;
    my $base_sleep = 10; # Base Sleep set to 1/10th of a second
    my $temp;
    
    #diag("Object Wait Threshold: $self->{wait_threshold} seconds") unless not $self->{debug};
    while ($duration < $self->{wait_threshold}) {
	# Return PASS if present (and visible)
	return 1 unless not $self->is_present_and_visible($locator, $check_visibility);
	
	## Sleep for set period of time and check again
	$temp = ($base_sleep/1000) + $duration;
	diag("Not found in $duration second(s). Sleeping for $base_sleep milliseconds and trying again!") unless $temp > $self->{wait_threshold} or not QA::Test::Util->isTrue($self->{debug});
	sleep $base_sleep/1000 unless $temp > $self->{wait_threshold};
	$base_sleep *= 2;
	$duration = tv_interval($t0);
	last unless $temp <= $self->{wait_threshold};
    }
    
    return fail("Unable to find $locator after $duration seconds on page: '" . $self->get_location() . "'");
}

=begin NaturalDocs

    Group: HTML::TreeBuilder Interface

    Function: get_HTMLTree
	Returns a reference to a HTML::TreeBuilder object. This object is built by calling
	Selenium get_html_source() and the returned HTMl is passed constructor of HTML::TreeBuilder.
	
    Parameters:
	None
	
    Returns:
	A reference to a HTML::TreeBuilder object.
	
=cut

sub get_HTMLTree #()
{
    my $self = shift;
    
    $self->{html_tree} = HTML::TreeBuilder->new_from_content($self->get_html_source());
    return $self->{html_tree};
}

=begin NaturalDocs

    Function: delete_HTMLTree
	This cleans up the reference to a <HTML::TreeBuilder>. You should perform this after
	retreiving the content you need, otherwise it will continue to fill up memory. This operation explicitly
	destroys the element and all its descendants.
	
    Parameters:
	None
	
    Returns:
	None
	
=cut

sub delete_HTMLTree #()
{
    my $self = shift;
    $self->{html_tree}->delete() unless not defined $self->{html_tree};
}

=begin NaturalDocs

    Group: Performance Stats

    Function: captureNetworkTraffic
	This will enable capture network traffic for a given page. Traffic will be captured for first open operation and then each page load.
	
    Parameters:
	page_load_duration - page load duration which was captured in open_ok and wait_for_page_to_load_ok
	page_url - page url
	message - (Optional) Message provided with the wait page load operation.If none provided then no message is stored
	is_err_page - 1 if its a error page that we are dealing with. Network capture wont capture anything for error page
	
    Return:
	returns captured traffic
	
=cut

sub captureNetworkTraffic #()
{
    my ($self,%args) = @_;
    
    # If the page is an error page then don't do the network capture and set perf stats to 0
    # Else do the network capture and parse the results.
    diag((caller(0))[3]." is_err_page: $args{is_err_page}") if $self->{debug};
    if($args{is_err_page}) {
	# If the page is an error page then no need to capture network
	diag("Error page found. Not capturing traffic for the page.Setting stats to 0.");
	my $nc = QA::Test::Web::NetworkCapture->new('error_page',$args{page_load_duration},$args{page_url},$args{message});
	push(@{$self->{network_capture_results}}, $nc);
	return $nc;
    } else {
	my $raw_xml = $self->captureNetworkTrafficRaw('xml');
	
	if($raw_xml) {
	    # Page is not an error page and network capture successed
	    my $nc = QA::Test::Web::NetworkCapture->new($raw_xml,$args{page_load_duration},$args{page_url},$args{message});
	
	    # Store NetworkCapture Results
	    push(@{$self->{network_capture_results}}, $nc);
	    return $nc;
            
	} else {
	    # Page is not an error page and network capture failed
    	    diag("Unable to capture traffic for the page. Setting stats to 0.");
	    my $nc = QA::Test::Web::NetworkCapture->new('network_capture_failed',$args{page_load_duration},$args{page_url},$args{message});
	    push(@{$self->{network_capture_results}}, $nc);
	    return $nc;
	}
    }
}

=begin NaturalDocs

    Function: captureNetworkTrafficRaw
	Returns the network traffic seen by the browser, including headers, AJAX requests, status codes, and timings. When this function is called, the traffic log is cleared, so the returned content is only the traffic seen since the last call.

    Parameters:
	type - The type of data to return the network traffic as. Valid values are: json, xml, or plain.
	
    Return:
	traffic - the formatted traffic information from selenium server


=cut

sub captureNetworkTrafficRaw #($type)
{
    my $self = shift;
    eval {
	$self->do_command("captureNetworkTraffic", @_);
    }
}

=begin NaturalDocs

    Group: Major Selenium Overriden subroutines

    Function: start
    
=cut

sub start #()
{
    my $self = shift;
    
    # Set CaptureNetworkTraffic
    $self->{extensionJs} = '';
    $self->{captureNetworkTraffic} = 'captureNetworkTraffic=true';
    
    return if $self->{session_id};
    $self->{session_id} = $self->get_string("getNewBrowserSession", 
                                            $self->{browser_start_command}, 
                                            $self->{browser_url},
					    $self->{extensionJs},
					    $self->{captureNetworkTraffic});
}

=begin NaturalDocs

    Function: do_command
	An overided version from WWW::Selenium of the do_command. This version removes a line that
	removed all blank STRING's and undefined values in the @args variable; unfortunately, this created unwanted
	results when trying to captureNetworkTraffic in Perl.
	
    Parameters:
	command - The command to execute on Selenium
	args - The arguments for the command
	
    Result:
	The result of from the POST operation to Selenium Agent

=cut

sub do_command #($command, @args)
{
    my ($self, $command, @args) = @_;

    $self->{_page_opened} = 1 if $command eq 'open';

    # Check that user has called open()
    my %valid_pre_open_commands = (
        testComplete => 1,
        getNewBrowserSession => 1,
        setTimeout => 1,
    );
    if (!$self->{_page_opened} and !$valid_pre_open_commands{$command}) {
        die "You must open a page before calling $command. eg: \$sel->open('/');\n";
    }

    $command = URI::Escape::uri_escape($command);
    my $fullurl = "http://$self->{host}:$self->{port}/selenium-server/driver/";
    my $content = "cmd=$command";
    my $i = 1;
    
    # Removing this line because it strips empty STRINGS and undefined values from @args!
    #@args = grep defined, @args;
    my $count = @args;
    
    while (@args) {
        $content .= "&$i=" . URI::Escape::uri_escape_utf8(shift @args);
        $i++;
    }
    if (defined $self->{session_id}) {
        $content .= "&sessionId=$self->{session_id}";
    }
    print "---> Num Args $count\n" if $self->{verbose};
    print "---> Requesting $fullurl\n" if $self->{verbose};
    print "---> Content $content\n" if $self->{verbose};

    # We use the full version of LWP to make sure we issue an 
    # HTTP 1.1 request (SRC-25)
    my $ua = LWP::UserAgent->new;
    my $header = HTTP::Headers->new( Content_Type => 'application/x-www-form-urlencoded; charset=utf-8' );
    my $response = $ua->request( HTTP::Request->new( 'POST', $fullurl, $header, $content ) );
    my $result;
    if ($response->is_success) {
        $result = $response->content;
        print "Got result: $result\n" if $self->{verbose};
    }
    else {
        die "Error requesting $fullurl:\n" . $response->status_line . "\n";
    }
    $result = decode_utf8($result) if $encode_present;
    die "Error requesting $fullurl:\n$result\n" unless $result =~ /^OK/;
    return $result;
}

1;
