package Plack::App::GAMobile;

use strict;
use warnings;
use parent qw/Plack::Component/;
use Carp;
use URI;
use URI::QueryParam;
use List::Util qw/first/;
use Furl;
use Net::DNS::Lite;
use Digest::MD5;
use Plack::Request;
use Plack::Request;

use Plack::Util::Accessor qw/secret timeout/;

our $VERSION = '0.01';

our $GAM_VERSION = '4.4sp';
our $GAM_COOKIE_NAME = '__utmmobile';
our $GAM_COOKIE_PATH = '/';
our $GAM_COOKIE_USER_PERSISTENCE = '+2y';
our $GAM_UTM_GIF_LOCATION = "http://www.google-analytics.com/__utm.gif";

my $GIF_DATA = pack "C43", (
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61,
    0x01, 0x00, 0x01, 0x00, 0x80, 0xff,
    0x00, 0xc0, 0xc0, 0xc0, 0x00, 0x00,
    0x00, 0x21, 0xf9, 0x04, 0x01, 0x00,
    0x00, 0x00, 0x00, 0x2c, 0x00, 0x00,
    0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
    0x00, 0x02, 0x02, 0x44, 0x01, 0x00,
    0x3b );

sub prepare_app {
    my $self = shift;
    Carp::croak "secret key must be defined" if ! $self->secret;
    $self->timeout(5) unless defined $self->timeout;
}

sub param_or {
    my ($req, $key, $val) = @_;
    return $req->param($key) if defined $req->param($key);
    return $val;
}

sub call {
    my $self = shift;
    my $env = shift;
    my $req = Plack::Request->new($env);

    my $domain_name = param_or($req, 'utmhn', "");
    my $document_referer = param_or($req, 'utmr', "-");
    my $document_path = param_or($req, 'utmp', "");
    my $account = param_or($req, 'utmac', "");
    my $utmn = param_or($req, 'utmn', "");

    if ( ! $req->param('cs') ) {
        return ['403', ['Content-Type' => 'text/plain'], ['no checksum'] ];
    }
    if ( $req->param('cs') ne
             substr( Digest::MD5::md5_hex($self->secret . $utmn . $domain_name . $document_path), 16, 6 ) ) {
        return ['403', ['Content-Type' => 'text/plain'], ['checksum not match'] ];
    }

    my $user_agent = "";
    if ( defined $req->user_agent ) {
        $user_agent = $req->user_agent;
    }

    my $remote_address = "";
    if ( defined $req->address ) {
        $remote_address = $req->address;
        if ($remote_address =~ /^((\d{1,3}\.){3})\d{1,3}$/) {
            $remote_address = $1 . "0";
        } else {
            $remote_address = "";
        }
    }

    srand(); #for preforking
    my $visitor_id = $self->get_visitor_id($req, $user_agent, $account);
    
    my $utm_url = URI->new($GAM_UTM_GIF_LOCATION);
    $utm_url->query_form_hash({
        utmwv  => $GAM_VERSION,
        utmn   => int(rand 0x7fffffff),
        utmhn  => $domain_name,
        utmr   => $document_referer,
        utmp   => $document_path,
        utmac  => $account,
        utmcc  => '__utma=999.999.999.999.999.1;',
        utmvid => $visitor_id,
        utmip  => $remote_address
    });

    my @headers;
    if (defined $req->header("Accept-Language") ) {
        push @headers, "Accept-Language", $req->header("Accept-Language");
    }
    
    my $furl = Furl::HTTP->new(
        inet_aton => \&Net::DNS::Lite::inet_aton,
        timeout   => $self->timeout,
        agent     => $user_agent,
        headers   => \@headers,
    );
    $furl->env_proxy;
    my ($minor_version, $status, $message, $headers, $content) = $furl->get("$utm_url");

    if ( substr( $status, 0, 1 ) ne '2' ) {
        Carp::carp "Failed request to '$GAM_UTM_GIF_LOCATION': $message";
    }

    my $res = Plack::Response->new(200);
    $res->content_type('image/gif');
    $res->header('Cache-Control', 'private, no-cache, no-cache=Set-Cookie, proxy-revalidate');
    $res->header('Pragma', 'no-cahce');
    $res->cookies->{$GAM_COOKIE_NAME} = {
        value => $visitor_id,
        path => $GAM_COOKIE_PATH,
        expires => $GAM_COOKIE_USER_PERSISTENCE,
    };
    $res->body($GIF_DATA);

    return $res->finalize;
}

sub get_visitor_id {
    my ($self, $req, $user_agent, $account) = @_;

    my $guid = first { defined $_ } map { $req->env->{$_}  } (
        "HTTP_X_DCMGUID",
        "HTTP_X_UP_SUBNO",
        "HTTP_X_JPHONE_UID",
        "HTTP_X_EM_UID"
    );
    $guid = "" if ! defined $guid;

    my $cookie = "";
    if ( defined $req->cookies->{$GAM_COOKIE_NAME} ) {
        $cookie = $req->cookies->{$GAM_COOKIE_NAME};
    }

    return $cookie if ($cookie ne "");

    my $message = "";
    if ($guid ne "") {
        $message = $guid . $account;
    } else {
        $message = $user_agent . int(rand 0x7fffffff );
    }

    my $md5_string = Digest::MD5::md5_hex($message);
    return "0x" . substr($md5_string, 0, 16);
}


1;
__END__

=head1 NAME

Plack::App::GAMobile - Google Analytics Mobile Beacon 

=head1 SYNOPSIS

  use Plack::App::GAMobile;
  use Plack::Builder;

  builder {
      mount "/gam" => Plack::App::GAMobile->new(
          secret => 'my very secret key',
          timeout => 4,
      );
  };

  # in app

  use Plack::GAMobile

  my $gam = Plack::GAMobile->new(
      secret => 'my very secret key',
      base_url => '/gam',
      account => 'ACCOUNT ID GOES HERE',
  );

  my $image_url = $gam->image_url($env);

  # in template
  <img src="[% image_url %]" />

=head1 DESCRIPTION

The server-side application for Google Analytics Mobile.

=head1 AUTHOR

Masahiro Nagano E<lt>kazeburo {at} gmail.comE<gt>

=head1 SEE ALSO

L<Plack::GAMobile>, L<http://code.google.com/intl/ja/mobile/analytics/>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
