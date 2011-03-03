use inc::Module::Install;
name 'WWW-GoogleAnalytics-Mobile';
all_from 'lib/WWW/GoogleAnalytics/Mobile.pm';

requires 'Furl', 0.31;
requires 'URI';
requires 'List::Util';
requires 'Net::DNS::Lite';
requires 'Digest::DM5';
requires 'Plack', 0.9963;
requires 'parent';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
