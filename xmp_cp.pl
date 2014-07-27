#!/usr/bin/env perl 

use strict;
use warnings;

use File::Spec;
use File::Find;
use File::Copy;
use Digest::MD5;
use Getopt::Long;
use Pod::Usage;

my $options = {};
GetOptions($options, qw/help man dry-run|r src|s=s dst|d=s/) or pod2usage(2);
pod2usage(1) if $options->{'help'};
pod2usage(-exitstatus => 0, -verbose => 2) if $options->{'man'};

unless (
    $options->{'src'} && -e $options->{'src'} && -d _ &&
    $options->{'dst'} && -e $options->{'dst'} && -d _
) {
    pod2usage(1);
}

for my $type ( qw| src dst | ) {
    next if File::Spec->file_name_is_absolute($options->{$type});

    $options->{$type} = File::Spec->rel2abs($options->{$type});
}

my $results = {
};

sub xmp_wanted {
    return unless /\.xmp$/i;

    my $dir  = $File::Find::dir;
    my $file = $_;
    my $full = $File::Find::name;

    my $cr2_ext  = _cr2_for_xmp($full);
    my $cr2_full = $full;
    my $cr2      = $file;

    $cr2_full =~ s/xmp$/$cr2_ext/i;
    $cr2      =~ s/xmp$/$cr2_ext/i;

    unless ($cr2) {
        print "CR2 for $file not found - skipping\n";
        return;
    }

    my $md5 = file_md5($cr2);
    unless ($md5) {
        print "Can't calculate MD5 on $cr2 file - skipping\n";
        return;
    }

    $results->{$cr2} = {
        md5      => $md5,
        xmp_full => $full,
    };
}

sub cr2_wanted {
    return unless exists $results->{$_};

    my $dir  = $File::Find::dir;
    my $file = $_;
    my $full = $File::Find::name;

    my $md5 = file_md5($full);
    unless ($md5) {
        print "Can't calculate MD5 on $full file - skipping\n";
        return;
    }
    if ($md5 ne $results->{$file}->{'md5'}) {
        print "Src cr2 and dst cr2 ($full) does not match - skipping\n";
        return;
    }

    print "Copy file $results->{$file}->{'xmp_full'} to $dir\n";
    unless ($options->{'dry-run'}) {
        copy($results->{$file}->{'xmp_full'}, $dir) or print "Error copying file ($results->{$file}->{'xmp_full'}): $!\n";
    }

    delete $results->{$file};
}

print "Collecting information\n";
find(\&xmp_wanted, $options->{'src'});
print "Going to copy\n";
find(\&cr2_wanted, $options->{'dst'});

if (keys %$results) {
    print "For the following XMP files we could not find original directory:\n";
    for my $k ( keys %$results ) {
        print "$results->{$k}->{'xmp_full'}\n";
    }
}

sub file_md5 {
    my $file = shift;
    my $md5  = Digest::MD5->new;
    my $fh;

    open($fh, '<', $file) or return '';
    $md5->addfile($fh);

    return $md5->hexdigest;
}

sub _cr2_for_xmp {
    my $file = shift;

    $file =~ s/xmp$//i;
    # a bit hacky way ;) Next time, let's make XML parsing
    for my $ext ( qw(CR2 cr2 Cr2 cR2) ) {
        my $new = "$file$ext";

        return $ext if -e $new;
    }

    return '';
}

__END__

=head1 NAME

xmp_cp.pl - Copy xmp files to folder with original copy of images.

=head1 SYNOPSIS

xmp_cp.pl [options]

    Options:
        --src           source folder with xmp files
        --dst           destination folder with images
        --dry-run       do not copy, just show what you'll make
        --help          brief help message
        --man           full documentation

=head1 OPTIONS

=over 8

=item B<< --src >>

Path to the temporary folder with C<< .xmp >> files.

=item B<< --dst >>

Path to the original top folder of the Photos.

=item B<< --dry-run >>

Make a dry run, not the actual copy of the files.

=item B<< --help >>

Print a brief help message and exits.

=item B<< --man >>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

I'm using Shotwell as a Photo organizer and it put my photos in folders like
this:

YEAR/MONTH/DAY/*.CR2

When I'm processing photo, I'm usually copy files to the separate folder and
process them there. But Adobe Camer Raw, leaves C<< .xmp >> files and I want to
store them for the history in the folder where the actual photo present. So
this programs helps copy C<< .xmp >> files back to the original folder.

=cut
