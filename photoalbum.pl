#!/usr/bin/perl
use strict;
use warnings;
use Switch 'Perl6';

use File::Find;
use PDF::Create;

sub get_images {
	my @ret;

	find({wanted => sub {
		if (/\.jpg/) {
			push @ret, $File::Find::name;
		}
	}, follow => 1}, './JPEG');
	return @ret;
}

sub scale {
	my ($w, $h, $default_width) = @_;
	my $ratio = $h / $w;
	return ($default_width, int($default_width * $ratio));
}

my $pagesize = 'Letter';
my $filename = 'album.pdf';
my $author = 'Leonardo Herrera';
my $title = '2009';
my $pdf = new PDF::Create(
	'filename'     => $filename,
	'Version'      => 1.2,
	'PageMode'     => 'UseOutlines',
	'Author'       => $author,
	'Title'        => $title,
	'CreationDate' => [ localtime ],
);
my $psz = $pdf->get_page_size($pagesize);
my $root = $pdf->new_page('MediaBox' => $psz);

my @images = (get_images)[0..5];
my $page = $root->new_page;
my ($accum, $y) = (0, 0);
my ($pw, $ph) = (@$psz)[2,3];



sub decide_layout {
	my $n = scalar @_;
	given ($n) {
		when 1 { return (1, 1); }
		when 2 { return (1, 2); }
		when 3 { return (1, 3); }
		when 4 { return (2, 2); }
		when 5 { return (2, 3); }
		when 6 { return (2, 3); }
		when 7 { return (2, 4); }
		when 8 { return (2, 4); }
		when 9 { return (3, 3); }
		when 12 { return (3, 4); }
		default { die "Wrong layout number: $_"; }
	}
}


sub max {
	my $max;

	foreach (@_) {
		$max = $_ unless $max && $max > $_;
	}
	return $max;
}

sub layout {
	my ($page, $pw, $ph, @images) = @_;

	my $max_width = max map { $$_{width} } @images;
	my $max_height = max map { $$_{height} } @images;

	print "max: $max_width : $max_height\n";
	exit;
}

while (@images) {
	my $n = 2;
	my @batch = map { $pdf->image($_) } splice @images, 0, $n;
	my $page = $root->new_page;

	layout($page, $pw, $ph, @batch);

	my $imup = shift @images;
	foreach my $im ($imup) {
		my $img = $pdf->image($im);
		my $xscale = $pw / $$img{width};
		my $img_h = $$img{height} * $xscale;
		if ($accum + $img_h  > $ph) {
			$page = $root->new_page;
			$accum = $$img{height} * $xscale;
		}
		my $y = $ph - $accum;
		$page->image(image => $img,
			xpos => 0, ypos => $y,
			xscale => $xscale,
			yscale => $xscale,
		);
	}
}

$pdf->close;
