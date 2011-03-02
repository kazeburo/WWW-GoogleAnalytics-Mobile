package Plack::GAMobile;

use strict;
use warnings;
use Carp;
use Digest::MD5;
use URI;
use URI::QueryParam;

use Plack::Util::Accessor qw/base_url account secret/;

sub new {
    my $class = shift;
    my $self;
    if (@_ == 1 && ref $_[0] eq 'HASH') {
        $self = bless {%{$_[0]}}, $class;
    } else {
        $self = bless {@_}, $class;
    }

    Carp::croak "google analytics mobile beacon base_url is needed" unless $self->base_url;
    Carp::croak "google analytics account id is needed" unless $self->account;
    Carp::croak "sercret key for checksum is needed" unless $self->secret;

    $self;
}

sub image_url {
    my $self = shift;
    my $env = shift;

    my $utmn = int(rand 0x7fffffff );
    my $referer = defined $env->{HTTP_REFERER} ? $env->{HTTP_REFERER} : "-";
    my $path = defined $env->{REQUEST_URI} ? $env->{REQUEST_URI} : "";

    my $domain = "";
    if ( defined $env->{HTTP_HOST} ) {
        $domain = $env->{HTTP_HOST};
    }
    elsif ( defined $env->{SERVER_NAME} ) {
        $domain = $env->{SERVER_NAME};
    }

    #guid cleanup
    if ( $referer ne "-") {
        my $r_uri = URI->new($referer);
        $r_uri->query_param_delete('guid');
        $referer = $r_uri->as_string;
    }

    my $digest = substr( Digest::MD5::md5_hex($self->secret . $utmn . $domain . $path), 16, 6 );

    my $url = URI->new($self->base_url);
    $url->query_form_hash({
        utmac => $self->account,
        utmn  => $utmn,
        utmhn => $domain,
        utmr  => $referer,
        utmp  => $path,
        cs    => $digest,
        guid  => 'ON',
    });
    return $url;
}

1;

__END__

=head1 NAME

Plack::GAMobile - Google Analytics Mobile Beacon Image URL generator

=head1 SYNOPSIS

use Plack::GAMobile;

  my $gam = Plack::GAMobile->new(
      secret => 'my very secret key',
      base_url => '/gam',
      account => 'ACCOUNT ID GOES HERE',
  );

  my $image_url = $gam->image_url($env);

  # in template
  <img src="[% image_url %]" />

=head1 DESCRIPTION

Plack::GAMobile is Plack::App::GAMobile's client. This module generate beacon image url.

=head1 METHOD

=over 4

=item new

Create instance of Plack::GAMobile.

=over 4

=item base_url

Base URL of beacon image.

=item secret

Secret key of making checksum. Set same secret of Plack::App::GAMobile.

=item account

Account ID of your Google Analytics ID.

=back

=item image_url($env)

generate beacon image url. $env is PSGI env.

=back

=head1 AUTHOR

Masahiro Nagano E<lt>kazeburo {at} gmail.comE<gt>

=head1 SEE ALSO

L<Plack::App::GAMobile>, L<http://code.google.com/intl/ja/mobile/analytics/>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

