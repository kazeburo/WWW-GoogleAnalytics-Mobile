use inc::Module::Install;
name 'Plack-App-GAMobile';
all_from 'lib/Plack/App/GAMobile.pm';

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
