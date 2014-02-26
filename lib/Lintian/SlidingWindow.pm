# -*- perl -*-
# Lintian::Data -- interface to match using a sliding window algorithm

# Copyright (C) 2013 Bastien ROUCARIÈS
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::SlidingWindow;

use strict;
use warnings;
use autodie;

use Carp qw(croak);

use Lintian::Util qw(strip);

sub new {
    my ($class, $mode, $file, $blocksub) = @_;
    open(my $handle, $mode, $file);

    my $self = {
        '_handle'      => $handle,
        '_queue'       => [q{}, q{}],
        '_blocksize'   => 4096,
        '_blocksub'    => $blocksub,
        '_blocknumber' => -1,
    };

    return bless($self, $class);
}

sub readwindow {
    my ($self) = @_;
    my ($window, $queue);
    {
        # This path is too hot for autodie at its current performance
        # (at the time of writing, that would be autodie/2.23).
        # - Benchmark chromium-browser/32.0.1700.123-2/source
        no autodie qw(read);
        my $res = read($self->{'_handle'}, $window, $self->{'_blocksize'});
        if (not $res) {
            die "read failed: $!\n" if not defined($res);
            return;
        }
    }

    if(defined($self->{'_blocksub'})) {
        local $_ = $window;
        $self->{'_blocksub'}->();
        $window = $_;
    }

    $self->{'_blocknumber'}++;

    $queue = $self->{'_queue'};
    shift(@{$queue});
    push(@{$queue}, $window);
    return join('', @{$queue});
}

sub blocknumber {
    my ($self) = @_;
    if($self->{'_blocknumber'} == -1) {
        return;
    }
    return $self->{'_blocknumber'};
}

=head1 NAME

Lintian::SlidingWindow - Lintian interface to sliding window match

=head1 SYNOPSIS

    use Lintian::SlidingWindow;

    my $sfd = Lintian::SlidingWindow->new('<','someevilfile.c', sub { $_ = lc($_); });
    my $window;
    while ($window = $sfd->readwindow()) {
       if (index($window, 'evil') > -1) {
           if($window =~
                 m/software \s++ shall \s++
                   be \s++ used \s++ for \s++ good \s*+ ,?+ \s*+
                   not \s++ evil/xsim) {
              # do something like : tag 'license-problem-json-evil';
           }
       }
    }

=head1 DESCRIPTION

Lintian::SlidingWindow provides a way of matching some pattern,
including multi line pattern, without needing to fully load the
file in memory.

=head1 CLASS METHODS

=over 4

=item new(mode,file,[blocksub])

Create a new sliding window for file file using mode mode. Optionally run blocksub against
each block. Note that blocksub should apply transform byte by byte and does not depend of context.

=back

=head1 INSTANCE METHODS

=over 4

=item readwindow

Return a new block of sliding window. Return undef at end of file.

=item blocknumber

return the number of block read by the instance. Return undef if no block has been read.

=back

=head1 DIAGNOSTICS

=over 4

=item no data type specified

=back

=head1 AUTHOR

Originally written by Bastien ROUCARIES for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
