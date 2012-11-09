=begin NaturalDocs

    This is a Utility module for commonly used operations used in  QA::Test libraries;
    it allows people to more easily and effectively write automated web tests that are
    specific to QA. This module specifically encapsulates useful Time modules for
    timestamping and for statistical evaluation.
    
=cut
package QA::Test::Util::Time;

use strict;
use Carp qw(croak);
use Exporter 'import';
use Test::More;
use Time::HiRes qw( gettimeofday tv_interval );

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

our @EXPORT = qw(get_formatted_time);

our @EXPORT_OK = qw(
    getTime_YYMMDD
    getTime_YYMMDDhhmm
    getTime_YYMMDDhhmmss
    getHttpTime
    getTimeFormatted
    startTime
    elapsedTime
);

=begin NaturalDocs

    Group: Functions
    
    Function: getTime_YYMMDD
	Generates a STRING timestamp of given format
	
    Parameters:
	split - (Optional) Splits the string with '-' dashes. Default is 0 (false)
    
    Return:
	str - STRING containing the specified date format
	
    Example:
	(begin code)
	# output: 10-01-02 (Jan 2nd, 2010)
	getTime_YYMMDD( split=>1 );
	
	# output: 100102 (Jan 2nd, 2010)
	getTime_YYMMDD();
	(end)

=cut

sub getTime_YYMMDD #(split=>1)
{
    my (%args) = @_;
    
    $args{split} = 0 unless defined $args{split};
    my ($second, $minute, $hour, $dayOfMonth, $month, $year, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = get_formatted_time();
    
    my $results = qq|$year-$month-$dayOfMonth|;
    $results =~ s/-//g unless QA::Test::Util->isTrue($args{split});
    
    return $results;
}

=begin NaturalDocs

    Function: getTime_YYMMDDhhmm
	Generates a STRING timestamp of given format
	
    Parameters:
	split - (Optional) Splits the string with '-' dashes. Default is 0 (false)
    
    Return:
	str - STRING containing the specified date format
	
    Example:
	(begin code)
	# output: 10-01-02-22-30 (Jan 2nd, 2010 10:30pm)
	getTime_YYMMDDhhmm( split=>1 );
	
	# output: 1001022230 (Jan 2nd, 2010 10:30pm)
	getTime_YYMMDDhhmm();
	(end)

=cut

sub getTime_YYMMDDhhmm #(split=>1)
{
    my (%args) = @_;
    
    $args{split} = 0 unless defined $args{split};
    my ($second, $minute, $hour, $dayOfMonth, $month, $year, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = get_formatted_time();
    
    my $results = qq|$year-$month-$dayOfMonth-$hour-$minute|;
    $results =~ s/-//g unless QA::Test::Util->isTrue($args{split});
    
    return $results;
}

=begin NaturalDocs

    Function: getTime_YYMMDDhhmmss
	Generates a STRING timestamp of given format
	
    Parameters:
	split - (Optional) Splits the string with '-' dashes. Default is 0 (false)
    
    Return:
	str - STRING containing the specified date format
	
    Example:
	(begin code)
	# output: 10-01-02-22-30-42 (Jan 2nd, 2010 10:30:42pm)
	getTime_YYMMDDhhmmss( split=>1 );
	
	# output: 100102223042 (Jan 2nd, 2010 10:30:42pm)
	getTime_YYMMDDhhmmss();
	(end)

=cut

sub getTime_YYMMDDhhmmss #(split=>1)
{
    my (%args) = @_;
    
    $args{split} = 0 unless defined $args{split};
    my ($second, $minute, $hour, $dayOfMonth, $month, $year, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = get_formatted_time();
    
    my $results = qq|$year-$month-$dayOfMonth-$hour-$minute-$second|;
    $results =~ s/-//g unless QA::Test::Util->isTrue($args{split});
    
    return $results;
}

=begin NaturalDocs

    Function: get_formatted_time
	Gets the formatted time string that is used for <getTime_YYMMDDhhmmss()>, <getTime_YYMMDDhhmm()>, and <getTime_YYMMDD()>.
	
    Parameters:
	None
	
    Returns:
	An array containing the following: ($second, $minute, $hour, $dayOfMonth, $month, $year, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings)
	
    Example:
	(begin code)
	    my ($second, $minute, $hour, $dayOfMonth, $month, $year, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = get_formatted_time();
	(end)
	
=cut

sub get_formatted_time #()
{
    my $self = shift;
    
    my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
    my $year = sprintf("%02d", $yearOffset % 100);
    $month++;
    $month = sprintf("%02d", $month);
    $dayOfMonth = sprintf("%02d", $dayOfMonth);
    $hour = sprintf("%02d", $hour);
    $minute = sprintf("%02d", $minute);
    $second = sprintf("%02d", $second);
    
    return ($second, $minute, $hour, $dayOfMonth, $month, $year, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings);
}

=begin NaturalDocs

    Function: getHttpTime
        Generates a human readable time string suitable for use in HTTP headers (e.g.,
        'Tue, 5 May 2009 GMT')  Note that GMT will always be used.

    Return:
        str - STRING containing the specified date format

=cut

sub getHttpTime #()
{
    my $self = shift;

    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
    my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = gmtime();
    my $year = 1900 + $yearOffset;
    $hour = sprintf("%02d", $hour);
    $minute = sprintf("%02d", $minute);
    $second = sprintf("%02d", $second);
    my $zone = "GMT";
    my $theTime = "$weekDays[$dayOfWeek], $dayOfMonth $months[$month] $year $hour:$minute:$second $zone";
    return $theTime;
}

=begin NaturalDocs

    Function: getTimeFormatted
	Generates a human readable time string (e.g., '12:36:18, Tue May 5, 2009')
	
    Return:
	str - STRING containing the specified date format

=cut

sub getTime #()
{
    my $self = shift;
    
    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
    my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
    my $year = 1900 + $yearOffset;
    $hour = sprintf("%02d", $hour);
    $minute = sprintf("%02d", $minute);
    $second = sprintf("%02d", $second);
    my $theTime = "$hour:$minute:$second, $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";
    return $theTime;
}

=begin NaturalDocs

    Function: startTime
	Returns the start time from Time::HiRes
	
    Parameters:
	None
	
    Returns:
	[gettimeofday] from Time::HiRes
	
=cut

sub startTime #()
{
    my $self = shift;
    return [gettimeofday];
}

=begin NaturalDocs

    Function: elapsedTime
	Returns the elapsed time passed from given start time.
	
    Parameters:
	start_time - The start time relative to now.
	
    Returns:
	The elapsed time period relative to start
	
=cut

sub elapsedTime #($start_time)
{
    my ($start_time) = @_;
    
    croak "start_time is undefined ".(caller(0))[3]."!" unless defined $start_time;
    return tv_interval($start_time, [gettimeofday]);
}

1;