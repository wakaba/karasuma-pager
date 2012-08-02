package Karasuma::Pager::Calendar::Basic;
use strict;
use warnings;
use base qw(Karasuma::Pager);
use Karasuma::Pager::Util::Date qw(
    html_week_string_to_datetime
    html_month_string_to_datetime
    html_date_string_to_datetime
    datetime_to_html_date_string
    datetime_to_html_week_string
    datetime_to_html_month_string
);
use Karasuma::URL;
use DateTime;

sub is_calendar { 1 }

# ------ Locale ------

__PACKAGE__->mk_accessors(qw(locale));

sub locale_tz : Caches {
    my $self = shift;
    my $locale = $self->locale or return 'UTC';
    return $locale->tz;
}

# ------ Date ------

__PACKAGE__->mk_accessors(qw(date date_delta date_level_default));

sub date_level {
    my $self = shift;
    $self->date_as_datetime unless $self->{date_level};
    return $self->{date_level};
}

my $validate_date_level = sub {
    my $value = shift or return undef;
    if ($value eq 'day' or $value eq 'week' or $value eq 'month' or $value eq 'year') {
        return $value;
    }
    return undef;
};

sub set_date_level {
    my $self = shift;
    my $value = shift or return;
    if ($validate_date_level->($value)) {
        $self->date_as_datetime;
        $self->{date_level} = $value;
    }
}

sub date_as_datetime : Caches {
    my $self = shift;
    my $date = $self->date or do {
        $self->{date_level} = $validate_date_level->($self->date_level_default) || 'day';
        my $dt = DateTime->today(time_zone => 'UTC');
        $dt->set_time_zone('floating');
        $dt->set_time_zone($self->locale_tz);
        return $self->_apply_delta($dt);
    };
    
    my $dt = html_date_string_to_datetime $date;
    if ($dt) {
        $self->{date_level} = 'day';
        $dt->set_time_zone('floating');
        $dt->set_time_zone($self->locale_tz);
        return $self->_apply_delta($dt);
    }

    $dt = html_week_string_to_datetime $date;
    if ($dt) {
        $self->{date_level} = 'week';
        $dt->set_time_zone('floating');
        $dt->set_time_zone($self->locale_tz);
        return $self->_apply_delta($dt);
    }

    $dt = html_month_string_to_datetime $date;
    if ($dt) {
        $self->{date_level} = 'month';
        $dt->set_time_zone('floating');
        $dt->set_time_zone($self->locale_tz);
        return $self->_apply_delta($dt);
    }

    if ($date =~ /^([0-9]+)$/) {
        $dt = eval { DateTime->new(year => $1, month => 1, day => 1) };
        if ($dt) {
            $self->{date_level} = 'year';
            $dt->set_time_zone($self->locale_tz);
            return $self->_apply_delta($dt);
        }
    }

    $dt = DateTime->today(time_zone => 'UTC');
    $self->{date_level} = $validate_date_level->($self->date_level_default) || 'day';
    $dt->set_time_zone('floating');
    $dt->set_time_zone($self->locale_tz);
    return $self->_apply_delta($dt);
}

sub _apply_delta {
    my $self = shift;
    my $dt = shift;
    my $delta = $self->date_delta || 0;
    my $level = $self->date_level;

    # Workaroung for DateTime's DST handling problem
    my $sign = $delta > 0 ? +1 : -1;
    $delta *= $sign;
    if ($level eq 'year') {
        $delta = 50 if $delta > 50;
    } elsif ($level eq 'month') {
        $delta = 50 * 12 if $delta > 50 * 12;
    } else {
        $delta = 50 * 12 * 24 if $delta > 50 * 12 * 24;
    }
    $delta *= $sign;

    $dt->add($level . 's' => $delta+0);
    return $dt;
}

sub start_as_datetime : Caches {
    my $self = shift;
    return $self->date_as_datetime;
}

sub end_as_datetime : Caches {
    my $self = shift;
    my $dt = $self->newer_date_as_datetime->clone;
    $dt->subtract(seconds => 1);
    return $dt;
}

sub older_date_as_datetime : Caches {
    my $self = shift;
    my $date = $self->date_as_datetime;
    my $level = $self->date_level;
    if ($level eq 'month') {
        $date = $date->clone->subtract(months => 1);
        return $date;
    } elsif ($level eq 'week') {
        $date = $date->clone->subtract(weeks => 1);
        return $date;
    } elsif ($level eq 'year') {
        $date = $date->clone->subtract(years => 1);
        return $date;
    } else {
        $date = $date->clone->subtract(days => 1);
        return $date;
    }
}

sub newer_date_as_datetime : Caches {
    my $self = shift;
    my $date = $self->date_as_datetime;
    my $level = $self->date_level;
    if ($level eq 'month') {
        $date = $date->clone->add(months => 1);
        return $date;
    } elsif ($level eq 'week') {
        $date = $date->clone->add(weeks => 1);
        return $date;
    } elsif ($level eq 'year') {
        $date = $date->clone->add(years => 1);
        return $date;
    } else {
        $date = $date->clone->add(days => 1);
        return $date;
    }
}

# ------ Calendar ------

sub month_calendar_datetime {
    my $self = shift;
    return $self->date_as_datetime;
}

sub month_calendar_as_arrayref : Caches {
    my $self = shift;
    my $date = $self->month_calendar_datetime;
    
    require Calendar::Simple;

    # calendar() が返すのは、 [[undef, ..., undef, 1, 2, 3], [4, 5, ...], ...]
    my $calendar = Calendar::Simple::calendar($date->month, $date->year, 1);
    return $calendar;
}

sub get_relative_day_type {
    my $self = shift;
    my $day = shift or return 'na';
    my $date_level = $self->date_level;
    if ($date_level eq 'day') {
        my $selected = $self->date_as_datetime->day;
        if ($selected == $day) {
            return 'current';
        } elsif ($day < $selected) {
            return 'older';
        } else {
            return 'newer';
        }
    } elsif ($date_level eq 'week') {
        return $self->get_relative_week_type_by_day($day);
    } else {
        return 'na';
    }
}

sub get_relative_week_type_by_day {
    my $self = shift;
    my $day = shift or return 'na';
    my $date_level = $self->date_level;
    if ($date_level eq 'day' or $date_level eq 'week') {
        my $dt = $self->date_as_datetime;
        my ($year1, $week1) = ($dt->week);
        $dt = $dt->clone;
        $dt->set_day($day);
        my ($year2, $week2) = ($dt->week);
        if ($year1 < $year2 or ($year1 == $year2 and $week1 < $week2)) {
            return 'newer';
        } elsif ($year1 == $year2 and $week1 == $week2) {
            return 'current';
        } else {
            return 'older';
        }
    } else {
        return 'na';
    }
}

sub get_holiday_type {
    my $self = shift;
    my $day = shift or return 'na';
    my $dt = $self->date_as_datetime->clone;
    $dt->set_day($day);
    my $dow = $dt->day_of_week;
    # XXX i18ned holiday support
    if ($dow == 6) {
        return 'saturday';
    } elsif ($dow == 7) {
        return 'sunday';
    } else {
        return 'na';
    }
}

sub get_absolute_day_type {
    my $self = shift;
    my $day = shift or return 'na';
    my $dt = $self->date_as_datetime->clone;
    $dt->set_day($day);
    my $selected = DateTime->now(time_zone => $self->locale_tz);
    if ($selected->ymd('-') eq $dt->ymd('-')) {
        return 'current';
    } elsif ($dt < $selected) {
        return 'older';
    } else {
        return 'newer';
    }
}

sub get_absolute_week_type_by_day {
    my $self = shift;
    my $day = shift or return 'na';
    my ($year1, $week1) = (DateTime->now(time_zone => $self->locale_tz)->week);
    my $dt = $self->date_as_datetime->clone;
    $dt->set_day($day);
    my ($year2, $week2) = ($dt->week);
    if ($year1 < $year2 or ($year1 == $year2 and $week1 < $week2)) {
        return 'newer';
    } elsif ($year1 == $year2 and $week1 == $week2) {
        return 'current';
    } else {
        return 'older';
    }
}

# ------ URLs ------

sub unpaged_url {
    my $self = shift;
    if (@_) {
        $self->{unpaged_url} = shift;
    }
    return $self->{unpaged_url} || Karasuma::URL->new;
}

sub get_url_with_date_and_level {
    my $self = shift;
    my $dt = shift || DateTime->now(time_zone => 'UTC');
    my $level = shift || 'day';

    my $locale = $self->locale;
    if ($locale) {
        $dt = $locale->in_local_tz($dt); # cloned
        $dt->set_time_zone('floating');
    }
    
    my $date;
    if ($level eq 'year') {
        $date = $dt->year;
    } elsif ($level eq 'month') {
        $date = datetime_to_html_month_string $dt;
    } elsif ($level eq 'week') {
        $date = datetime_to_html_week_string $dt;
    } else {
        $date = datetime_to_html_date_string $dt;
    }

    my $url = $self->unpaged_url->clone;
    $url->qparams->{date} = $date;
    return $url;
}

sub current_url : Caches {
    my $self = shift;
    return $self->get_url_with_date_and_level($self->date_as_datetime, $self->date_level);
}

sub older_url : Caches {
    my $self = shift;
    return $self->get_url_with_date_and_level($self->older_date_as_datetime, $self->date_level);
}

sub newer_url : Caches {
    my $self = shift;
    return $self->get_url_with_date_and_level($self->newer_date_as_datetime, $self->date_level);
}

sub older_delta_url : Caches {
    my $self = shift;
    return $self->current_url->clone->set_qparam(date_delta => -1);
}

sub newer_delta_url : Caches {
    my $self = shift;
    return $self->current_url->clone->set_qparam(date_delta => 1);
}

sub week_url_by_day {
    my $self = shift;
    my $day = shift;
    my $dt = $self->month_calendar_datetime->clone;
    $dt->set_day($day);
    return $self->get_url_with_date_and_level($dt, 'week');
}

sub day_url {
    my $self = shift;
    my $day = shift;
    my $dt = $self->month_calendar_datetime->clone;
    $dt->set_day($day);
    return $self->get_url_with_date_and_level($dt, 'day');
}

sub get_day_qualified_url {
    my $self = shift;
    my $u = shift;
    my $url = $self->day_url(shift);
    $u->set_qparam(date => $url->qparams->{date});
    return $u;
}

__PACKAGE__->cache_methods;

1;
