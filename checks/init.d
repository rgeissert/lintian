#!/usr/bin/perl -w
# init.d -- lintian check script

# Copyright (C) 1998 Christian Schwarz
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, you can find it on the World Wide
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
# MA 02111-1307, USA.

use strict;

($#ARGV == 1) or fail("syntax: init.d <pkg> <type>");
my $pkg = shift;
my $type = shift;

my $postinst = "control/postinst";
my $preinst = "control/preinst";
my $postrm = "control/postrm";
my $prerm = "control/prerm";
my $conffiles = "control/conffiles";

my %initd_postinst;
my %initd_postrm;
my %conffiles;

# read postinst control file
if (open(IN,$postinst)) {
    while (<IN>) {
	next if m/if\s+\[\s+-x\s+\S*update-rc\.d/o;
	s/\#.*$//o;
	next unless /^(?:.+;)?\s*update-rc\.d\s+(?:-\S+\s*)*(\S+)\s+(\S+)/;
	my ($name,$opt) = ($1,$2);
	next if $opt eq 'remove';
	if ($initd_postinst{$name}++ == 1) {
	    print "E: $pkg $type: duplicate-updaterc.d-calls-in-postinst $name\n";
	    next;
	}
	unless (m,>\s*/dev/null,o) {
	    print "I: $pkg $type: output-of-updaterc.d-not-redirected-to-dev-null $name postinst\n";
	}
    }
}
close(IN);

# read preinst control file
if (open(IN,$preinst)) {
    while (<IN>) {
	next if m/if\s+\[\s+-x\s+\S*update-rc\.d/o;
	s/\#.*$//o;
	next unless m/update-rc\.d\s+(?:-\S+\s*)*(\S+)\s+(\S+)/o;
	my ($name,$opt) = ($1,$2);
	next if $opt eq 'remove';
	print "E: $pkg $type: preinst-calls-updaterc.d $name\n";
    }
    close(IN);
}

# read postrm control file
if (open(IN,$postrm)) {
    while (<IN>) {
	next if m/if\s+\[\s+-x\s+\S*update-rc\.d/o;
	s/\#.*$//o;
	next unless m/update-rc\.d\s+(-\S+\s*)*(\S+)/;
	if ($initd_postrm{$2}++ == 1) {
	    print "E: $pkg $type: duplicate-updaterc.d-calls-in-postrm $2\n";
	    next;
	}
	unless (m,>\s*/dev/null,o) {
	    print "E: $pkg $type: output-of-updaterc.d-not-redirected-to-dev-null $2 postrm\n";
	}
    }
    close(IN);
}

# read prerm control file
if (open(IN,$prerm)) {
    while (<IN>) {
	next if m/if\s+\[\s+-x\s+\S*update-rc\.d/o;
	s/\#.*$//o;
	next unless m/update-rc\.d\s+(-\S+\s*)*(\S+)/;
	print "E: $pkg $type: prerm-calls-updaterc.d $2\n";
    }
    close(IN);
}

# init.d scripts have to be removed in postrm
for (keys %initd_postinst) {
    if ($initd_postrm{$_}) {
	delete $initd_postrm{$_};
    } else {
	print "E: $pkg $type: postrm-does-not-call-updaterc.d-for-init.d-script /etc/init.d/$_\n";
    }
}
for (keys %initd_postrm) {
    print "E: $pkg $type: postrm-contains-additional-updaterc.d-calls /etc/init.d/$_\n";
}

# load conffiles
if (open(IN,$conffiles)) {
    while (<IN>) {
	chop;
	next if m/^\s*$/o;
	$conffiles{$_} = 1;

	if (m,^/?etc/rc.\.d,o) {
	    print "E: $pkg $type: file-in-etc-rc.d-marked-as-conffile $_\n";
	}
    }
    close(IN);
}

for (keys %initd_postinst) {
    # init.d scripts have to be marked as conffiles
    unless ($conffiles{"/etc/init.d/$_"} or $conffiles{"etc/init.d/$_"}) {
	print "E: $pkg $type: init.d-script-not-marked-as-conffile /etc/init.d/$_\n";
    }

    # check if file exists in package
    my $initd_file = "init.d/$_";
    if (-f $initd_file) {
	# yes! check it...
	open(IN,$initd_file) or fail("cannot open init.d file $initd_file: $!");
	my %tag;
	while (defined(my $l = <IN>)) {
	    while ($l =~ s/(start|stop|restart|force-reload)//o) {
		$tag{$1} = 1;
	    }
	}
	close(IN);

	# all tags included in file?
	$tag{'start'} or print "E: $pkg $type: init.d-script-does-not-implement-required-option /etc/init.d/$_ start\n";
	$tag{'stop'} or print "E: $pkg $type: init.d-script-does-not-implement-required-option /etc/init.d/$_ stop\n";
	$tag{'restart'} or print "E: $pkg $type: init.d-script-does-not-implement-required-option /etc/init.d/$_ restart\n";
	$tag{'force-reload'} or print "E: $pkg $type: init.d-script-does-not-implement-required-option /etc/init.d/$_ force-reload\n";
    } else {
	print "E: $pkg $type: init.d-script-not-included-in-package /etc/init.d/$_\n";
    }
}

# files actually installed in /etc/init.d should match our list :-)
opendir(INITD, "init.d") or fail("cannot read init.d directory: $!");
for (readdir(INITD)) {
    next if $_ eq '.' || $_ eq '..';
    print "W: $pkg $type: script-in-etc-init.d-not-registered-via-update-rc.d /etc/init.d/$_\n"
	unless $initd_postinst{$_};
}
closedir(INITD);

exit 0;

# -----------------------------------

sub fail {
    if ($_[0]) {
	warn "internal error: $_[0]\n";
    } elsif ($!) {
	warn "internal error: $!\n";
    } else {
	warn "internal error.\n";
    }
    exit 1;
}
