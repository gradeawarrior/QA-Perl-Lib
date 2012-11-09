# Description

A set of perl libraries that you can import (via PERL5LIB environment variable). The current code contains many useful test libraries for testing WebApplications. At a high-level, you can find the following:

1. Standalone Webservice test libraries that extend and enhance the LWP libraries and brings testing context around it.
2. Enhanced Selenium 1.0 test library
3. TestRunner framework

# Installation

Once you have the project checked-out to your system. Add the following to your ~/.bashrc or ~/.bash_profile

	## Path to QA-Perl-Lib
	export PERL5LIB=<YOUR_PATH>/QA-Perl-Lib
	
Unfortunately with Perl, you will have to install several libraries. The hard way of course is to run one of classes in the library and resolve your dependencies. The other way is to run the cpan installer:

	$ cd cpan
	$ ./install-CPAN-Modules.sh

> **WARNING**: *The installation of any CPAN library is a difficult and sometimes painful task; it often fails to install a specific library depending on the machine and operating system you are installing on. You may have to manually install required libraries on your system and possibly do a 'force' to get the appropriate library installed. Sometimes you may need to isntall as root and sometimes you can install as a normal user. The installer script unfortunately does not handle all cases, and should be used to aid in getting all required libraries installed.*

For the TestRunner framework, you will need the *test_runner* script. You can either copy (or symlink) this file into your scripts directory, or add a new entry in /etc/paths.d/:

	$ sudo vi /etc/paths.d/testrunner
	
And add the following contents:

	<YOUR_PATH>/QA-Perl-Lib/


# Documentation

## Webservices Test Library

The QA::Test::WebService::Session Perl Library is used by QA for automating the REST/ATOM API tests. It's a framework sitting on top of LWP::UserAgent to make API testing and reporting easier but at the same time gives the user full control over HTTP::Response object for advanced tasks.

For more information, see the following wiki: [Webservices Test Library](https://github.com/gradeawarrior/QA-Perl-Lib/wiki/WebServices-Test-Session-Library)

## TestRunner Framework
The purpose of the Test Runner framework is to help drive and organize QA Functional and Integration Testing, specifically in the world of Perl! [Perl](http://en.wikipedia.org/wiki/Perl) is one of those age-old scripting/programming languages that has proven itself over the years, earning the nickname "the Swiss Army chainsaw of programming languages". However, many of the advantages of using perl end up being also some of the disadvantages of using it. 

For testing, it allows engineers to quickly write a test for their specific product and incorporate the popular [Test::More](http://search.cpan.org/~mschwern/Test-Simple-0.96/lib/Test/More.pm) library for verification checks. Unfortunately, these end up what I call "one-off" test scripts; in other words, test scripts that only said engineer knows how to run and knows how to interpret given output. In Java, there are two popular test frameworks that developers can implement and use: TestNG and JUnit. These Java test frameworks help an organization standardize the writing and execution of tests for a given project. 

The goal of the Test Runner framework is to bring a similar test framework to the world of Perl. Leveraging the same or similar patterns that are used in [code-driven testing](http://en.wikipedia.org/wiki/Test_automation), the hope is to standardize and better organize the creation of Tests and ultimately Test Suites that define a collection of Tests that make up: 

1. the testing of a single product or service 
2. the end-to-end testing of a suite of products 
3. the entire collection of products of an organization 
4. the entire collection of tests owned by different organizations 

The basis of the framework is based on the [xUnit Pattern](http://en.wikipedia.org/wiki/XUnit). See the wiki page for a high-level explanation. This will help in the understanding of the design and use of the Test Runner framework, however, Test Runner closely resembles JUnit and thus engineers familiar with this framework should feel at home. 


For more information, see the following wiki: [TestRunner - Unit Test Framework](https://github.com/gradeawarrior/QA-Perl-Lib/wiki/Test-Runner-Unit-Test-Framework)