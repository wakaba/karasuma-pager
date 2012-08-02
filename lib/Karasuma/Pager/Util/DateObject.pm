package Karasuma::Pager::Util::DateObject;
use strict;
use warnings;
our $VERSION = '1.0';

my $default_level = {must => 'm', unsupported => 'u'};
my $default_onerror = sub {
  my %opt = @_;
  my @msg = ($opt{type});
  push @msg, $opt{value} if defined $opt{value};
  warn join '; ', @msg, "\n";
};

sub new ($) {
  my $self = bless {}, shift;

  ## Public fields
  $self->{onerror} = $default_onerror;
  $self->{level} = $default_level;
  
  return $self;
} # new

sub _create_object ($$$$$$$$$;$) {
  #my ($self, $y, $M, $d, $h, $m, $s, $zh, $zm, $diff) = @_;
  my $self = shift;

  my $class = 'Karasuma::Pager::Util::DateObject::TimeT';
#  unless ($DateTime::VERSION) {
#    eval { require DateTime };
#  }
#  if ($DateTime::VERSION) {
#    $class = 'Karasuma::Pager::Util::DateObject::DateTime';
#  }
  
  bless $self, $class;
  return $self->_set_value (@_);
} # _create_object

sub _is_leap_year ($) {
  return ($_[0] % 400 == 0 or ($_[0] % 4 == 0 and $_[0] % 100 != 0));
} # _is_leap_year

sub _last_week_number ($) {
  ## ISSUE: HTML5 definition is wrong. <http://en.wikipedia.org/wiki/ISO_week_date#Relation_with_the_Gregorian_calendar>
  my $jan1_dow = [gmtime Time::Local::timegm (0, 0, 0, 1, 1 - 1, $_[0])]->[6];
  return ($jan1_dow == 4 or
          ($jan1_dow == 3 and _is_leap_year ($_[0]))) ? 53 : 52;
} # _last_week_number

sub _week_year_diff ($) {
  my $jan1_dow = [gmtime Time::Local::timegm (0, 0, 0, 1, 1 - 1, $_[0])]->[6];
  if ($jan1_dow <= 4) {
    return $jan1_dow - 1;
  } else {
    return $jan1_dow - 8;
  }
} # _week_year_diff

## Time string [HTML5]
sub parse_time_string ($$) {
  my ($self, $value) = @_;
  $self = $self->new unless ref $self;
  
  if ($value =~ /\A
                 ([0-9]{2}):([0-9]{2})(?>:([0-9]{2})(?>(\.[0-9]+))?)?
                 \z/x) {
    my ($h, $m, $s, $sf) = ($1, $2, $3, $4);
    $self->{onerror}->(type => 'datetime:bad hour',
                       level => $self->{level}->{must}), return undef if $h > 23;
    $self->{onerror}->(type => 'datetime:bad minute',
                       level => $self->{level}->{must}), return undef if $m > 59;
    $s ||= 0;
    $self->{onerror}->(type => 'datetime:bad second',
                       level => $self->{level}->{must}), return undef if $s > 59;
    $sf = defined $sf ? $sf : '';

    if (defined wantarray) {
      return $self->_create_object (1970, 1, 1, $h, $m, $s, $sf, 0, 0);
    }
  } else {
    $self->{onerror}->(type => 'time:syntax error', ## TODOC: type
                       level => $self->{level}->{must});
    return undef;
  }
} # parse_time_string

## Time string [HTML5]
sub to_time_string ($) {
  my $self = shift;
  
  return sprintf '%02d:%02d:%02d%s',
      $self->utc_hour, $self->utc_minute,
      $self->utc_second, $self->second_fraction_string;
} # to_time_string

## Week string [HTML5]
sub parse_week_string ($$) {
  my ($self, $value) = @_;
  $self = $self->new unless ref $self;
  
  if ($value =~ /\A([0-9]{4,})-W([0-9]{2})\z/x) {
    my ($y, $w) = ($1, $2);
    $self->{onerror}->(type => 'datetime:bad year',
                       level => $self->{level}->{must}), return undef if $y == 0;
    $self->{onerror}->(type => 'week:bad week', ## TODOC: type
                       level => $self->{level}->{must}), return undef
        if $w > _last_week_number ($y) || $w == 0;
    
    if (defined wantarray) {
      my $day = ($w - 1) * 7 - _week_year_diff ($y);
    
      return $self->_create_object ($y, 1, 1, 0, 0, 0, '', 0, 0,
                                    $day * 24 * 3600 * 1000);
    }
  } else {
    $self->{onerror}->(type => 'week:syntax error', ## TODOC: type
                       level => $self->{level}->{must});
    return undef;
  }
} # parse_week_string

## Week string [HTML5]
sub to_week_string ($) {
  my $self = shift;
  
  return sprintf '%04d-W%02d', $self->utc_week_year, $self->utc_week;
} # to_week_string

## Month string [HTML5]
sub parse_month_string ($$) {
  my ($self, $value) = @_;
  $self = $self->new unless ref $self;
  
  if ($value =~ /\A([0-9]{4,})-([0-9]{2})\z/) {
    my ($y, $M) = ($1, $2);
    if ($y == 0) {
      $self->{onerror}->(type => 'datetime:bad year',
                         level => $self->{level}->{must});
      return undef;
    }

    if (0 < $M and $M < 13) {
      #
    } else {
      $self->{onerror}->(type => 'datetime:bad month',
                         level => $self->{level}->{must});
      return undef;
    }

    if (defined wantarray) {
      return $self->_create_object ($y, $M, 1, 0, 0, 0, '', 0, 0);
    }
  } else {
    $self->{onerror}->(type => 'month:syntax error', ## TODOC: type
                       level => $self->{level}->{must});
    return undef;
  }
} # parse_month_string

## Month string [HTML5]
sub to_month_string ($) {
  my $self = shift;
  
  return sprintf '%04d-%02d', $self->utc_year, $self->utc_month;
} # to_month_string

## Date string [HTML5]
sub parse_date_string ($$) {
  my ($self, $value) = @_;
  $self = $self->new unless ref $self;
  
  if ($value =~ /\A([0-9]{4,})-([0-9]{2})-([0-9]{2})\z/x) {
    my ($y, $M, $d) = ($1, $2, $3);
    $self->{onerror}->(type => 'datetime:bad year',
                       level => $self->{level}->{must}), return undef if $y == 0;
    if (0 < $M and $M < 13) {
      $self->{onerror}->(type => 'datetime:bad day',
                         level => $self->{level}->{must}), return undef
          if $d < 1 or
              $d > [0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]->[$M];
      $self->{onerror}->(type => 'datetime:bad day',
                         level => $self->{level}->{must}), return undef
          if $M == 2 and $d == 29 and
              not ($y % 400 == 0 or ($y % 4 == 0 and $y % 100 != 0));
    } else {
      $self->{onerror}->(type => 'datetime:bad month',
                         level => $self->{level}->{must});
      return undef;
    }

    if (defined wantarray) {
      return $self->_create_object ($y, $M, $d, 0, 0, 0, '', 0, 0);
    }
  } else {
    $self->{onerror}->(type => 'date:syntax error', ## TODOC: type
                       level => $self->{level}->{must});
    return undef;
  }
} # parse_date_string

## Date string [HTML5]
sub to_date_string ($) {
  my $self = shift;
  
  return sprintf '%04d-%02d-%02d',
      $self->utc_year, $self->utc_month, $self->utc_day;
} # to_date_string

## Local date and time string [HTML5]
sub parse_local_date_and_time_string ($$) {
  my ($self, $value) = @_;
  $self = $self->new unless ref $self;
  
  if ($value =~ /\A([0-9]{4,})-([0-9]{2})-([0-9]{2})T
                 ([0-9]{2}):([0-9]{2})(?>:([0-9]{2})(?>(\.[0-9]+))?)?\z/x) {
    my ($y, $M, $d, $h, $m, $s, $sf) = ($1, $2, $3, $4, $5, $6, $7);

    $self->{onerror}->(type => 'datetime:bad year',
                       level => $self->{level}->{must}), return undef if $y == 0;
    if (0 < $M and $M < 13) {
      $self->{onerror}->(type => 'datetime:bad day',
                         level => $self->{level}->{must}), return undef
          if $d < 1 or
              $d > [0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]->[$M];
      $self->{onerror}->(type => 'datetime:bad day',
                         level => $self->{level}->{must}), return undef
          if $M == 2 and $d == 29 and not _is_leap_year ($y);
    } else {
      $self->{onerror}->(type => 'datetime:bad month',
                         level => $self->{level}->{must});
      return undef;
    }
    $self->{onerror}->(type => 'datetime:bad hour',
                       level => $self->{level}->{must}), return undef if $h > 23;
    $self->{onerror}->(type => 'datetime:bad minute',
                       level => $self->{level}->{must}), return undef if $m > 59;
    $s ||= 0;
    $self->{onerror}->(type => 'datetime:bad second',
                       level => $self->{level}->{must}), return undef if $s > 59;
    $sf = defined $sf ? $sf : '';

    if (defined wantarray) {
      return $self->_create_object ($y, $M, $d, $h, $m, $s, $sf, '-00', 0);
    }
  } else {
    $self->{onerror}->(type => 'datetime-local:syntax error', ## TODOC: type
                       level => $self->{level}->{must});
    return undef;
  }
} # parse_local_date_and_time_string

## Local date and time string [HTML5]
sub to_local_date_and_time_string ($) {
  my $self = shift;
  
  return sprintf '%04d-%02d-%02dT%02d:%02d:%02d%s',
      $self->year, $self->month, $self->day,
      $self->hour, $self->minute, $self->second, $self->second_fraction_string;
} # to_local_date_and_time_string

## Global date and time string [HTML5]
sub parse_global_date_and_time_string ($$) {
  my ($self, $value) = @_;
  $self = $self->new unless ref $self;
  
  if ($value =~ /\A([0-9]{4,})-([0-9]{2})-([0-9]{2})T
                 ([0-9]{2}):([0-9]{2})(?>:([0-9]{2})(?>(\.[0-9]+))?)?
                 (?>Z|([+-][0-9]{2}):([0-9]{2}))\z/x) {
    my ($y, $M, $d, $h, $m, $s, $sf, $zh, $zm)
        = ($1, $2, $3, $4, $5, $6, $7, $8, $9);
    if (0 < $M and $M < 13) {
      $self->{onerror}->(type => 'datetime:bad day',
                         level => $self->{level}->{must}), return undef
          if $d < 1 or
              $d > [0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]->[$M];
      $self->{onerror}->(type => 'datetime:bad day',
                         level => $self->{level}->{must}), return undef
          if $M == 2 and $d == 29 and not _is_leap_year ($y);
    } else {
      $self->{onerror}->(type => 'datetime:bad month',
                         level => $self->{level}->{must});
      return undef;
    }
    $self->{onerror}->(type => 'datetime:bad year',
                       level => $self->{level}->{must}), return undef if $y == 0;
    $self->{onerror}->(type => 'datetime:bad hour',
                       level => $self->{level}->{must}), return undef if $h > 23;
    $self->{onerror}->(type => 'datetime:bad minute',
                       level => $self->{level}->{must}), return undef if $m > 59;
    $s ||= 0;
    $self->{onerror}->(type => 'datetime:bad second',
                       level => $self->{level}->{must}), return undef if $s > 59;
    $sf = defined $sf ? $sf : '';
    if (defined $zh) {
      $self->{onerror}->(type => 'datetime:bad timezone hour',
                         level => $self->{level}->{must}), return undef
          if $zh > 23 or $zh < -23;
      $self->{onerror}->(type => 'datetime:bad timezone minute',
                         level => $self->{level}->{must}), return undef
          if $zm > 59;
    } else {
      $zh = 0;
      $zm = 0;
    }
    if ($zh eq '-00' and $zm eq '00') {
      $self->{onerror}->(type => 'datetime:-00:00', # XXXtype
                         level => $self->{level}->{must}); # don't return
    }

    if (defined wantarray) {
      return $self->_create_object ($y, $M, $d, $h, $m, $s, $sf, $zh, $zm);
    }
  } else {
    $self->{onerror}->(type => 'datetime:syntax error',
                       level => $self->{level}->{must});
    return undef;
  }
} # parse_global_date_and_time_string

## Global date and time string [HTML5], always in UTC
sub to_global_date_and_time_string ($) {
  my $self = shift;
  
  return sprintf '%04d-%02d-%02dT%02d:%02d:%02d%sZ',
      $self->utc_year, $self->utc_month, $self->utc_day,
      $self->utc_hour, $self->utc_minute,
      $self->utc_second, $self->second_fraction_string;
} # to_global_date_and_time_string

## Date string with optional time [Web Applications 1.0]
sub parse_date_string_with_optional_time ($$) {
  my ($self, $value) = @_;
  $self = $self->new unless ref $self;
  
  if ($value =~ /\A([0-9]{4,})-([0-9]{2})-([0-9]{2})(?:T
                 ([0-9]{2}):([0-9]{2})(?>:([0-9]{2})(?>(\.[0-9]+))?)?
                 (?>Z|([+-][0-9]{2}):([0-9]{2})))?\z/x) {
    my ($y, $M, $d, $h, $m, $s, $sf, $zh, $zm)
        = ($1, $2, $3, $4, $5, $6, $7, $8, $9);
    if (0 < $M and $M < 13) {
      $self->{onerror}->(type => 'datetime:bad day',
                         level => $self->{level}->{must}), return undef
          if $d < 1 or
              $d > [0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]->[$M];
      $self->{onerror}->(type => 'datetime:bad day',
                         level => $self->{level}->{must}), return undef
          if $M == 2 and $d == 29 and not _is_leap_year ($y);
    } else {
      $self->{onerror}->(type => 'datetime:bad month',
                         level => $self->{level}->{must});
      return undef;
    }
    $self->{onerror}->(type => 'datetime:bad year',
                       level => $self->{level}->{must}), return undef if $y == 0;
    
    if (defined $h) {
      $self->{onerror}->(type => 'datetime:bad hour',
                         level => $self->{level}->{must}), return undef if $h > 23;
      $self->{onerror}->(type => 'datetime:bad minute',
                         level => $self->{level}->{must}), return undef if $m > 59;
      $s ||= 0;
      $self->{onerror}->(type => 'datetime:bad second',
                         level => $self->{level}->{must}), return undef if $s > 59;
      $sf = defined $sf ? $sf : '';
      if (defined $zh) {
        $self->{onerror}->(type => 'datetime:bad timezone hour',
                           level => $self->{level}->{must}), return undef
            if $zh > 23 or $zh < -23;
        $self->{onerror}->(type => 'datetime:bad timezone minute',
                           level => $self->{level}->{must}), return undef
            if $zm > 59;
      } else {
        $zh = 0;
        $zm = 0;
      }
      if ($zh eq '-00' and $zm eq '00') {
        $self->{onerror}->(type => 'datetime:-00:00', # XXXtype
                           level => $self->{level}->{must}); # don't return
      }

      if (defined wantarray) {
        return $self->_create_object ($y, $M, $d, $h, $m, $s, $sf, $zh, $zm);
      }
    } else {
      if (defined wantarray) {
        return $self->_create_object ($y, $M, $d, 0, 0, 0, 0, 0, 0);
      }
    }
  } else {
    $self->{onerror}->(type => 'dateandopttime:syntax error', ## XXXtype
                       level => $self->{level}->{must});
    return undef;
  }
} # parse_date_string_with_optional_time

sub timezone_offset_second ($) {
  my $self = shift;
  return $self->timezone_hour * 3600 + $self->timezone_minute * 60;
} # timezone_offset_second

sub utc_week ($) {
  my $self = shift;

  if (defined $self->{cache}->{utc_week}) {
    return $self->{cache}->{utc_week};
  }

  my $year = $self->utc_year;

  my $jan1 = __PACKAGE__->new->_create_object ($year, 1, 1, 0, 0, 0, 0, 0, 0);

  my $days = $self->to_unix_integer - $jan1->to_unix_integer;
  $days /= 24 * 3600;

  my $week_year_diff = _week_year_diff ($year);
  $days += $week_year_diff;

  my $week = int ($days / 7) + 1;
  
  if ($days < 0) {
    $year--;
    $week = _last_week_number ($year);
  } elsif ($week > _last_week_number ($year)) {
    $year++;
    $week = 1;
  }
  
  $self->{cache}->{utc_week_year} = $year;
  $self->{cache}->{utc_week} = $week;

  return $week;
} # utc_week

sub utc_week_year ($) {
  my $self = shift;
  $self->utc_week;
  return $self->{cache}->{utc_week_year};
} # utc_week_year

sub to_html5_month_number ($) {
  my $self = shift;

  ## ISSUE: "the number of months between January 1970 and the parsed
  ## month.": "between"?  inclusive or exclusive or anything else?
  ## months before 1970?

  my $y = $self->year - 1970;
  my $m = $self->month - 1;

  return $y * 12 + $m;
} # to_html5_month_number

package Karasuma::Pager::Util::DateObject::TimeT;
push our @ISA, 'Karasuma::Pager::Util::DateObject';

## TODO: Should be moved to a separate module.

require Time::Local;
my $unix_epoch = Time::Local::timegm (0, 0, 0, 1, 1 - 1, 1970);

sub _set_value ($$$$$$$$$$;$) {
  my $self = shift;
  my ($y, $M, $d, $h, $m, $s, $sf, $zh, $zm, $diff) = @_;
  
  $self->{value} = Time::Local::timegm_nocheck
      ($s, $m - $zm, $h - $zh, $d, $M-1, $y);
  $self->{timezone_hour} = $zh;
  $self->{timezone_minute} = $zm;

  if ($self->year != $y or
      $self->month != $M or
      $self->day != $d or
      $self->hour != $h or
      $self->minute != $m) {
    $self->{onerror}->(type => 'date value not supported',
                       value => join (", ", @_),
                       level => $self->{level}->{unsupported});
    return undef;
  }
  
  if ($diff) {
    my $v = $self->{value} . $sf;
    $v += $diff / 1000;
    my $int_v = int $v;
    if ($int_v != $v) {
      if ($v > 0) {
        $self->{value} = $int_v;
        $sf = $v - $int_v;
      } else {
        $self->{value} = $int_v - 1;
        $sf = $v - $int_v - 1;
      }
    } else {
      $self->{value} = $v;
      $sf = '';
    }
  }

  $self->{second_fraction} = $sf;

  delete $self->{cache};

  return $self;
} # _set_value

sub second_fraction_string ($) {
  my $self = shift;
  if ($self->{second_fraction}) {
    my $v = $self->{second_fraction};
    unless (substr ($v, 0, 1) eq '.') {
      $v = sprintf '%.100f', $v;
      $v = substr $v, 1;
    }
    $v = substr $v, 1;
    $v =~ s/0+\z//;
    return length $v ? '.' . $v :'';
  } else {
    return '';
  }
} # second_fraction_string

## Timezone component [HTML5]
sub timezone_string ($) {
  my $self = shift;
  if ($self->{timezone_hour} eq '-00') {
    return sprintf '-00:%02d', $self->{timezone_minute};
  } elsif ($self->{timezone_hour} == 0 and
           $self->{timezone_minute} == 0) {
    return 'Z';
  } elsif ($self->{timezone_hour} >= 0) {
    return sprintf '+%02d:%02d', $self->{timezone_hour}, $self->{timezone_minute};
  } else {
    return sprintf '-%02d:%02d',
        -$self->{timezone_hour}, $self->{timezone_minute};
  }
} # timezone_string

sub _utc_time ($) {
  my $self = shift;
  $self->{cache}->{utc_time} = [gmtime $self->{value}];
} # _utc_time

sub _local_time ($) {
  my $self = shift;
  $self->{cache}->{local_time} = [gmtime ($self->{value} + $self->timezone_offset_second)];
} # _local_time

sub year ($) {
  my $self = shift;
  $self->_local_time unless defined $self->{cache}->{local_time};
  return $self->{cache}->{local_time}->[5] + 1900;
} # year

sub month ($) {
  my $self = shift;
  $self->_local_time unless defined $self->{cache}->{local_time};
  return $self->{cache}->{local_time}->[4] + 1;
} # month

sub day ($) {
  my $self = shift;
  $self->_local_time unless defined $self->{cache}->{local_time};
  return $self->{cache}->{local_time}->[3];
} # day

sub day_of_week ($) {
  my $self = shift;
  $self->_local_time unless defined $self->{cache}->{local_time};
  return $self->{cache}->{local_time}->[6]; # 0..6
} # day_of_week

sub hour ($) {
  my $self = shift;
  $self->_local_time unless defined $self->{cache}->{local_time};
  return $self->{cache}->{local_time}->[2];
} # hour

sub minute ($) {
  my $self = shift;
  $self->_local_time unless defined $self->{cache}->{local_time};
  return $self->{cache}->{local_time}->[1];
} # minute

sub second ($) {
  my $self = shift;
  $self->_local_time unless defined $self->{cache}->{local_time};
  return $self->{cache}->{local_time}->[0];
} # second

sub fractional_second ($) {
  my $self = shift;
  return $self->second + $self->{second_fraction};
} # fractional_second

sub utc_year ($) {
  my $self = shift;
  $self->_utc_time unless defined $self->{cache}->{utc_time};
  return $self->{cache}->{utc_time}->[5] + 1900;
} # utc_year

sub utc_month ($) {
  my $self = shift;
  $self->_utc_time unless defined $self->{cache}->{utc_time};
  return $self->{cache}->{utc_time}->[4] + 1;
} # utc_month

sub utc_day ($) {
  my $self = shift;
  $self->_utc_time unless defined $self->{cache}->{utc_time};
  return $self->{cache}->{utc_time}->[3];
} # utc_day

sub utc_day_of_week ($) {
  my $self = shift;
  $self->_utc_time unless defined $self->{cache}->{utc_time};
  return $self->{cache}->{utc_time}->[6]; # 0..6
} # utc_day_of_week

sub utc_hour ($) {
  my $self = shift;
  $self->_utc_time unless defined $self->{cache}->{utc_time};
  return $self->{cache}->{utc_time}->[2];
} # utc_hour

sub utc_minute ($) {
  my $self = shift;
  $self->_utc_time unless defined $self->{cache}->{utc_time};
  return $self->{cache}->{utc_time}->[1];
} # utc_minute

sub utc_second ($) {
  my $self = shift;
  $self->_utc_time unless defined $self->{cache}->{utc_time};
  return $self->{cache}->{utc_time}->[0];
} # utc_second

sub utc_fractional_second ($) {
  my $self = shift;
  return $self->utc_second + $self->{second_fraction};
} # utc_fractional_second

sub timezone_hour ($) {
  my $self = shift;
  return $self->{timezone_hour};
} # timezone_hour

sub timezone_minute ($) {
  my $self = shift;
  return $self->{timezone_minute};
} # timezone_minute

sub to_html5_number ($) {
  my $self = shift;
  my $int = $self->{value} - $unix_epoch;
  my $frac = $self->second_fraction_string . '00000';
  $frac = substr $frac, 1; # remove leading "."
  substr ($frac, 4, 0) = '.';
  $frac =~ s/0+\z//;
  $frac =~ s/\.\z//;
  return $int . $frac;
} # to_html5_number

sub to_unix_integer ($) {
  my $self = shift;
  return $self->{value} - $unix_epoch;
} # to_unix_integer

sub to_datetime ($) {
  my $self = shift;
  require DateTime;
  return DateTime->from_epoch (epoch => $self->to_unix_integer);
} # to_datetime

package Karasuma::Pager::Util::DateObject::DateTime;
push our @ISA, 'Karasuma::Pager::Util::DateObject';

## TODO: Implement this module.  Use "floating" time_zone such that
## leap seconds are not taken into account.

=head1 LICENSE

Copyright 2008-2010 Wakaba <w@suika.fam.cx>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
