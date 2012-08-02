package Karasuma::Pager::Util::Date;
use strict;
use warnings;
use Exporter::Lite;

our @EXPORT;

sub _to_utc_or_utc_floating ($) {
    my $dt = shift or return;
    my $tz = $dt->time_zone->name;
    if ($tz eq 'UTC' or $tz eq 'floating') {
        return $dt;
    } else {
        $dt = $dt->clone;
        $dt->set_time_zone('UTC');
        return $dt;
    }
}

push @EXPORT, qw(datetime_to_html_date_string);
sub datetime_to_html_date_string ($) {
    my $dt = _to_utc_or_utc_floating(shift);
    return sprintf '%04d-%02d-%02d', $dt->year, $dt->month, $dt->day;
}

push @EXPORT, qw(html_date_string_to_datetime);
sub html_date_string_to_datetime ($) {
    require Karasuma::Pager::Util::DateObject;
    my $date = Karasuma::Pager::Util::DateObject->new;
    $date->{onerror} = sub { };
    
    my $dt = eval { $date->parse_date_string($_[0] || return undef) } or return undef;
    return $dt->to_datetime; # UTC
}

push @EXPORT, qw(datetime_to_html_month_string);
sub datetime_to_html_month_string ($) {
    my $dt = _to_utc_or_utc_floating(shift);
    return sprintf '%04d-%02d', $dt->year, $dt->month;
}

push @EXPORT, qw(html_month_string_to_datetime);
sub html_month_string_to_datetime ($) {
    require Karasuma::Pager::Util::DateObject;
    my $date = Karasuma::Pager::Util::DateObject->new;
    $date->{onerror} = sub { };
    
    my $dt = eval { $date->parse_month_string($_[0] || return undef) } or return undef;
    return $dt->to_datetime; # UTC
}

push @EXPORT, qw(datetime_to_html_week_string);
sub datetime_to_html_week_string ($) {
    my $dt = _to_utc_or_utc_floating(shift);

    # $dt->week は週年と年の2つの値を返す
    return sprintf '%04d-W%02d', ($dt->week);
}

push @EXPORT, qw(html_week_string_to_datetime);
sub html_week_string_to_datetime ($) {
    require Karasuma::Pager::Util::DateObject;
    my $date = Karasuma::Pager::Util::DateObject->new;
    $date->{onerror} = sub { };
    
    my $dt = eval { $date->parse_week_string($_[0] || return undef) } or return undef;
    return $dt->to_datetime; # UTC
}

1;
