#!/usr/bin/perl

################################################################################
# check-unused-keys - Perl Script to check unused indexes
# 
# @author Ryan Lowe <ryan.a.lowe@percona.com>
# @author Devananda Van Der Veen <deva@percona.com>
################################################################################

use strict;
use warnings FATAL => 'all';
use Pod::Usage;
use Getopt::Long;
use English qw(-no_match_vars);
use DBI;

my $VERSION = '0.0.6';
my %OPTIONS;
$OPTIONS{'summary'} = 1;

################################################################################
# Get configuration information
################################################################################

# Parse command line opts
my $gop=new Getopt::Long::Parser;
$gop->configure('no_ignore_case','bundling');
if (!$gop->getoptions(
    'create-alter!'        => \$OPTIONS{'createalter'   },
    'databases|d=s'        => \$OPTIONS{'database'      },
    'flush-tables!'        => \$OPTIONS{'flush'         },
    'help|h'               => \$OPTIONS{'help'          },
    'hostname|H=s'         => \$OPTIONS{'host'          },
    'ignore-databases=s'   => \$OPTIONS{'ignoredb'      },
    'ignore-indexes=s'     => \$OPTIONS{'ignoreidx'     },
    'ignore-primary-key!'  => \$OPTIONS{'ignorepk'      },   
    'ignore-tables=s'      => \$OPTIONS{'ignoretbl'     },
    'ignore-unused-tables!'
                           => \$OPTIONS{'ignoreunusedtbl'},
    'ignore-unique|ignore-unique-index!'
                           => \$OPTIONS{'ignoreuniq'    },
    'ignore-fulltext|ignore-fulltext-index!'
                           => \$OPTIONS{'ignoreft'      },
    'print-unused-tables!' => \$OPTIONS{'printunusedtbl'},
    'options-file=s'       => \$OPTIONS{'def'           },
    'password|p=s'         => \$OPTIONS{'password'      },
    'port=i'               => \$OPTIONS{'port'          },
    'socket|s=s'           => \$OPTIONS{'socket'        },
    'summary!'             => \$OPTIONS{'summary'       },
    'tables|t=s'           => \$OPTIONS{'tables'        },
    'username|u=s'         => \$OPTIONS{'user'          },
    'verbose|v+'           => \$OPTIONS{'verbose'       },
    'version|V'            => \$OPTIONS{'version'       } ) ) {

    pod2usage(2);
}

# Yay for versions
if ($OPTIONS{'version'}) {
    print "$VERSION\n";
    exit 0;
}

# Help if asked for or no check given
pod2usage(2) if     ($OPTIONS{'help'});

# Set global defaults/validate options
$OPTIONS{'timeout'} = $OPTIONS{'timeout'} ? $OPTIONS{'timeout'} : 10;
$OPTIONS{'verbose'} = $OPTIONS{'verbose'} ? $OPTIONS{'verbose'} : 0;

################################################################################
# Begin the main program
################################################################################

# Set db defaults/validate options
$OPTIONS{'host'} = $OPTIONS{'host'} ? $OPTIONS{'host'} : 'localhost';
$OPTIONS{'port'} = $OPTIONS{'port'} ? $OPTIONS{'port'} : '3306';
$OPTIONS{'def' } = $OPTIONS{'def' } ? $OPTIONS{'def' } : $ENV{'HOME'}.'/.my.cnf';

# Set some default behaviour
$OPTIONS{'createalter'}     = defined($OPTIONS{'createalter'})     ? $OPTIONS{'createalter'} : 0;
$OPTIONS{'ignorepk'}        = defined($OPTIONS{'ignorepk'})        ? $OPTIONS{'ignorepk'} : 1;
$OPTIONS{'ignoreunusedtbl'} = defined($OPTIONS{'ignoreunusedtbl'}) ? $OPTIONS{'ignoreunusedtbl'} : 1;
$OPTIONS{'ignoreuniq'}      = defined($OPTIONS{'ignoreuniq'})      ? $OPTIONS{'ignoreuniq'} : 1;
$OPTIONS{'ignoreft'}        = defined($OPTIONS{'ignoreft'})        ? $OPTIONS{'ignoreft'} : 1;
$OPTIONS{'printunusedtbl'}  = defined($OPTIONS{'printunusedtbl'})  ? $OPTIONS{'printunusedtbl'} : 0;

# Attempt db connection
my $connection_string  = 'DBI:mysql:';
$connection_string    .= "host=$OPTIONS{'host'};";
$connection_string    .= "database=$OPTIONS{'database'};"
    if $OPTIONS{'database'};
$connection_string    .= "mysql_socket=$OPTIONS{'socket'};"
    if $OPTIONS{'socket'} and $OPTIONS{'host'} eq 'localhost';
$connection_string    .= "port=$OPTIONS{'port'};";
$connection_string    .= "mysql_read_default_file=$OPTIONS{'def'};";
$connection_string    .= "mysql_read_default_group=client;";
$connection_string    .= "mysql_multi_statements=1";
my $dbh;
eval {
    $dbh = DBI->connect (
        $connection_string,
        $OPTIONS{'user'},
        $OPTIONS{'password'},
        { RaiseError => 1, PrintError => 0 }
    );
};

if ( $@ ) {
    print "Could not connect to MySQL\n";
    print "\n";
    print $@ if ($OPTIONS{'verbose'} > 0);
    exit 1;
}

# Check to make sure userstats is actually enabled:)

my $sanity_query = 'SHOW GLOBAL VARIABLES LIKE "userstat"';
my $sth = $dbh->prepare($sanity_query);
$sth->execute();

my $status = $sth->fetchrow_hashref();
die('userstat is NOT running') unless (defined($status->{'Value'}) and $status->{'Value'} eq 'ON'); 

if ($OPTIONS{'flush'}) {
    $dbh->do('FLUSH TABLES');
}

################################################################################
# Build The Query
################################################################################

my $query = '
SELECT DISTINCT `s`.`TABLE_SCHEMA`, `s`.`TABLE_NAME`, `s`.`INDEX_NAME`,
      `s`.`NON_UNIQUE`, `s`.`INDEX_NAME`, `i`.`ROWS_READ` AS IDX_READ
  FROM `information_schema`.`statistics` AS `s` 
  LEFT JOIN `information_schema`.`index_statistics` AS `i`
    ON (`s`.`TABLE_SCHEMA` = `i`.`TABLE_SCHEMA` AND 
        `s`.`TABLE_NAME`   = `i`.`TABLE_NAME` AND
        `s`.`INDEX_NAME`   = `i`.`INDEX_NAME`)
  WHERE `i`.`TABLE_SCHEMA` IS NULL
';

my $table_append = '';

if ($OPTIONS{'database'}) {
    my @dbs = split(',', $OPTIONS{'database'});
    $query .= '    AND `s`.`TABLE_SCHEMA` IN ("'.join('","',@dbs).'")
';
    $table_append .= '    AND `s`.`TABLE_SCHEMA` IN ("'.join('","',@dbs).'")
';
 
}

if ($OPTIONS{'ignoredb'}) {
    my @dbs = split(',', $OPTIONS{'ignoredb'});
    $query .= '    AND `s`.`TABLE_SCHEMA` NOT IN ("'.join('","',@dbs).'")
';
    $table_append .= '    AND `s`.`TABLE_SCHEMA` NOT IN ("'.join('","',@dbs).'")
';

}

if ($OPTIONS{'ignoretbl'}) {
    my @tbls = split(',', $OPTIONS{'ignoretbl'});
    foreach (@tbls) {
        my @a = split(/\./, $_); 
        $query .= '    AND (`s`.`TABLE_SCHEMA` != "'.$a[0].'" AND `s`.`TABLE_NAME` != "'.$a[1].'")
';
        $table_append .= '    AND (`s`.`TABLE_SCHEMA` != "'.$a[0].'" AND `s`.`TABLE_NAME` != "'.$a[1].'")
';
    } 
}

if ($OPTIONS{'ignoreidx'}) {
    my @idxs = split(',', $OPTIONS{'ignoreidx'});
    foreach (@idxs) {
        my @a = split(/\./, $_);
        $query .= '    AND (`s`.`TABLE_SCHEMA` != "'.$a[0].'" AND `s`.`TABLE_NAME` != "'.$a[1].'" AND `s`.`INDEX_NAME` != "'.$a[2].'")
';
    }
}

if ($OPTIONS{'tables'}) {
    my @tbls = split(/\,/, $OPTIONS{'tables'});
    foreach (@tbls) {
        my @a = split(/\./, $_);
        $query .= '    AND (`s`.`TABLE_SCHEMA` = "'.$a[0].'" AND `s`.`TABLE_NAME` = "'.$a[1].'")
';
        $table_append .= '    AND (`s`.`TABLE_SCHEMA` = "'.$a[0].'" AND `s`.`TABLE_NAME` = "'.$a[1].'")
';
    }
}

if ($OPTIONS{'ignorepk'}) {
    $query .= '    AND `s`.`INDEX_NAME` != "PRIMARY"
';
}

if ($OPTIONS{'ignoreuniq'}) {
    $query .= '    AND `s`.`NON_UNIQUE` = 1
';
}

if ($OPTIONS{'ignoreft'}) {
    $query .= '    AND `s`.`INDEX_TYPE` != "FULLTEXT"
';
}

print $query."\n" if ($OPTIONS{'verbose'});

$sth = $dbh->prepare($query);
$sth->execute();

# Prepare a list of the unused tables
my $n_tbls = 0;
my $unused_tables = {};
my $unused_tables_query = '
SELECT DISTINCT `s`.`TABLE_SCHEMA`, `s`.`TABLE_NAME`
  FROM `INFORMATION_SCHEMA`.`TABLES` AS `s`
  LEFT JOIN `INFORMATION_SCHEMA`.`TABLE_STATISTICS` AS `t` ON (`s`.`TABLE_SCHEMA` = `t`.`TABLE_SCHEMA` AND `s`.`TABLE_NAME` = `t`.`TABLE_NAME`)
  WHERE `t`.`TABLE_SCHEMA` IS NULL
';
$unused_tables_query .= $table_append;

my $tsth = $dbh->prepare($unused_tables_query);
$tsth->execute();

while (my $row = $tsth->fetchrow_hashref()) {

    my $tbl = '`'.$row->{'TABLE_SCHEMA'}.'`.`'.$row->{'TABLE_NAME'}.'`';
    $unused_tables->{$tbl} = 1;
    $n_tbls++;

}

my $n_indexes = 0;
my $ignored_tbls = {};
my %alters;

while (my $row = $sth->fetchrow_hashref()) {

    my $tbl = '`'.$row->{'TABLE_SCHEMA'}.'`.`'.$row->{'TABLE_NAME'}.'`';

    ## if this table was never read from
    if (exists($unused_tables->{$tbl})) {
        ## skip if we already printed this table
        next if ($ignored_tbls->{$tbl});

        $ignored_tbls->{$tbl} = 1;

        print "# Table $tbl not used.\n"  if ($OPTIONS{'printunusedtbl'} gt 0);
        
        ## dont bother doing check for unused indexes if table was never read
        ## but not if --no-ignore-unused-tables is set
        if ($OPTIONS{'ignoreunusedtbl'}) {
	    next;
        }
    }

    ## build the ALTER command
    $n_indexes++;
    if ($OPTIONS{'createalter'}) {
        if (!defined($alters{$tbl})) {
            $alters{$tbl} = 'ALTER TABLE '.$tbl.' DROP INDEX `'.$row->{'INDEX_NAME'}.'`';
        } else {
            $alters{$tbl} .= ",\n    DROP INDEX `".$row->{'INDEX_NAME'}.'`';
        }
    }
    print "# Index $tbl (".$row->{'INDEX_NAME'}.") not used.\n";
}

if ($OPTIONS{'createalter'}) {
    foreach (sort keys %alters)  {
       print $alters{$_}.";\n";
    }
}

if ($OPTIONS{'summary'} gt 0) {
    $sth = $dbh->prepare('SHOW GLOBAL STATUS LIKE "Uptime"');
    $sth->execute();
    my $ua = $sth->fetchrow_hashref();

    print '
################################################################################
# Unused Indexes: '.$n_indexes,"\n";

    print '# Unused Tables:  '.$n_tbls."\n" if $OPTIONS{'printunusedtbl'};
    print '# Uptime: '.$ua->{'Value'}.' seconds
################################################################################
';
}

=pod

=head1 NAME

check-unused-keys - Perl Script to check unused indexes using Percona userstat

=head1 SYNOPSIS

 check-unused-keys [OPTIONS]

 Options:
   -d, --databases=<dbname>  Comma-separated list of databases to check
   -h, --help                Display this message and exit
   -H, --hostname=<hostname> The target MySQL server host
   --[no]create-alter        Print ALTER statements for each table
   --ignore-databases        Comma-separated list of databases to ignore
   --ignore-indexes          Comma-separated list of indexes to ignore
                                 db_name.tbl_name.index_name
   --ignore-tables           Comma-separated list of tables to ignore
                                 db_name.tbl_name
   --[no]ignore-unused-tables
                             Whether or not to show indexes from unused
                                 tables
   --[no]ignore-primary      Whether or not to ignore PRIMARY KEY
   --[no]ignore-unique       Whether or not to ignore UNIQUE indexes
   --[no]ignore-fulltext     Whether or not to ignore FULLTEXT indexes
   --options-file            The options file to use
   --[no]print-unused-tables 
                             Whether or not to print a list of unused tables
   -p, --password=<password> The password of the MySQL user
   -i, --port=<portnum>      The port MySQL is listening on
   -s, --socket=<sockfile>   Use the specified mysql unix socket to connect
   -t, --tables=<tables>     Comma-separated list of tables to evaluate
                                 db_name.tbl_name
   --[no]summary             Display summary information
   -u, --username=<username> The MySQL user used to connect
   -v, --verbose             Increase verbosity level
   -V, --version             Display version information and exit

 Defaults are:

 ATTRIBUTE                  VALUE
 -------------------------- ------------------
 databases                  ALL databases 
 help                       FALSE
 hostname                   localhost
 create-alter               FALSE
 ignore-databases           No default value
 ignore-indexes             No default value
 ignore-unused-tables       TRUE
 ignore-primary             TRUE
 ignore-tables              No default value
 ignore-unique              TRUE
 ignore-fulltext            TRUE
 options-file               ~/.my.cnf
 password                   No default value
 print-unused-tables        FALSE
 port                       3306
 socket                     No default value
 summary                    TRUE
 tables                     No Default Value
 username                   No default value
 verbose                    0 (out of 2)
 version                    FALSE

=head1 SYSTEM REQUIREMENTS

check-unused-keys requires the following Perl modules:

  Pod::Usage
  Getopt::Long
  DBI
  DBD::mysql

=head1 BUGS

Please report all bugs and feature requests to
http://code.google.com/p/check-unused-keys

=head1 LICENSE

THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
systems, you can issue `man perlgpl' or `man perlartistic' to read these
licenses.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place, Suite 330, Boston, MA  02111-1307 USA.

=head1 AUTHOR

Ryan Lowe (ryan.a.lowe@percona.com)
Devananda Van Der Veen (deva@percona.com)

=head1 VERSION

This manual page documents 0.0.6 of check-unused-keys

=cut

