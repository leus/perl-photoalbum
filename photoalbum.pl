#!/usr/bin/perl
use strict;
use warnings;
use diagnostics;
use Switch 'Perl6';

use File::Find;
use PDF::Create;
use Image::ExifTool;

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

print "psz: ", join(', ', @$psz), "\n";
my $root = $pdf->new_page('MediaBox' => $psz);

#my @images = (get_images)[0..40];
my @images = get_images;
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
	foreach (@_) { $max = $_ unless $max && $max > $_; }
	return $max;
}


sub fit_img {
	my ($img, $slot_w, $slot_h) = @_;

	# aspect ratio
	my $ratio = $$img{height} / $$img{width};
	print "ratio: $ratio\n";
	return ($slot_w, int($slot_h * $ratio));
}


sub place_img {
	my ($page, $img, $w, $h, $slot_w, $slot_h, $x, $y) = @_;
	my $margin = 10;
	my $xscale;

	if (abs($$img{width} - $w) > abs($$img{height} - $h)) {
		$xscale = ($w - $margin * 2) / $$img{width};
	} else {
		$xscale = ($h - $margin * 2) / $$img{height};

	}
	my ($rw, $rh) = ($$img{width} * $xscale, $$img{height} * $xscale);

	$x *= $slot_w;
	$y *= $slot_h;
	$x += ($slot_w - $rw) / 2;
	$y += ($slot_h - $rh) / 2;

	$page->image(image => $img,
		xpos => $x,
		ypos => $y,
		xscale => $xscale,
		yscale => $xscale,
	);
}


sub layout {
	my ($page, $pw, $ph, @images) = @_;
	my $max_width = max map { $$_{width} } @images;
	my $max_height = max map { $$_{height} } @images;
	my ($w, $h) = decide_layout(@images);
	my ($slot_w, $slot_h) = ($pw / $w, $ph / $h);

	# margins
	my $margin = 20;

	for (my $j = 0; $j < $h; $j++) {
		for (my $i = 0; $i < $w; $i++) {
			my $im = shift @images;
			if ($im) {
				my ($w, $h) = fit_img($im, $slot_w, $slot_h);
				place_img($page, $im,
				    $w, $h,
				    $slot_w, $slot_h,
				    $i, $j);
			}
		}
	}
}

my @months = qw(Enero Febrero Marzo Abril
    Mayo Junio Julio Agosto Septiembre
    Octubre Noviembre Diciembre);

my $f = $pdf->font('Subtype'  => 'Type1',
	'Encoding' => 'WinAnsiEncoding',
	'BaseFont' => 'Helvetica');

my $exif = new Image::ExifTool;
my %dt;
sub get_pics_for_month {
	my ($m, $pics) = @_;
	my @results;
	my $x;
	foreach my $k (keys %$pics) {
		print "$m - $k... ";
		unless ($dt{$k}) {
			my $info = $exif->ImageInfo($k, 'DateTimeOriginal');
			die "info err"
			    unless $info->{DateTimeOriginal} =~ /^(\d{4}):(\d\d):(\d\d) (\d\d):(\d\d)/;
			$dt{$k} = {
				y => $1, m => $2, d => $3, 
				str => sprintf('%04d%02d%02d%02d%02d',
				$1, $2, $3, $4, $5) };
		}
		if ($m == $dt{$k}->{m} - 1) {
			print "matches.";
			push @results, $k;
			delete $pics->{$k};
		}
		print "\n";
	}
	return @results;
}

{
my $month = 0;
my %images = map { $_ => 1 } @images;
while (keys %images) {
	die "pics without date info?" if $month > 11;
	my @for_this_month = 
	    sort { $dt{$a}->{str} cmp $dt{$b}->{str} }
		get_pics_for_month($month, \%images);
	if (@for_this_month) {
		print "Pics for this month: ", scalar @for_this_month, "\n";
		$page = $root->new_page;
		$page->stringc($f, 40, 306, 426, $months[$month]);
		while (@for_this_month) {
			my $n = 6;
			my @to_proc = reverse splice @for_this_month, 0, $n;
			my @batch = map { $pdf->image($_) } @to_proc; 
			if (@batch) {
				my $page = $root->new_page;
				layout($page, $pw, $ph, @batch);
			}
		}
	}
	$month++;
}
}

$pdf->close;
