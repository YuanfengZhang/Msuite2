#!/usr/bin/perl
#
# Author: Kun Sun (sunkun@szbl.ac.cn)
# This program is part of Msuite2
# Date: Jul 2021
#

use strict;
use warnings;
use File::Basename;
use FindBin qw($Bin);
use lib $Bin;
use MsuiteUtil qw($version $ver $url);

#print STDERR "Usage: $0 [data.dir=.]\n";

my $dir = $ARGV[0] || '.';
my @color = ( '#E8DAEF', '#D6EAF8' );
my $minSpikeIn = 100;

unless( -d "$dir/Msuite2.report/" && -s "$dir/Msuite2.conf" ) {
	print STDERR "ERROR: Incorrect directory structure!\n";
	exit 1;
}
open OUT, ">$dir/Msuite2.report/index.html" or die("$!");
select OUT;

## load configuration file
## this file should be prepared by Msuite program while NOT the user
my $absPath=`readlink -m $0`;
chomp( $absPath );
my $Msuite = dirname($absPath);
$Msuite =~ s/bin\/?$/Msuite/;

open CONF, "$dir/Msuite2.conf" or die( "$!" );
my %conf;
#my $parameter = "<tr bgcolor=\"$color[0]\"><td>Msuite path</td><td>$Msuite</td></tr>\n";
my $parameter = "";
my $i = 1;
while( <CONF> ){
	chomp;
	next if /^#/;
	next unless /\S/;
	my @l = split /\t/;
	$conf{ $l[0] } = $l[1];
	if( $l[1] =~ /:/ ) {	## process R1:R2 files
		my ($r1, $r2) = split /:/, $l[1];
		$parameter .= "<tr bgcolor=\"$color[$i]\"><td>$l[0]</td><td>Read 1: $r1<br />Read 2: $r2</td></tr>\n";
	} else {
		$parameter .= "<tr bgcolor=\"$color[$i]\"><td>$l[0]</td><td>$l[1]</td></tr>\n";
	}
	$i = 1 - $i;
}
close CONF;

my $pe   = ( $conf{"Sequencing mode"}  =~ /^P/i   ) ? 1 : 0;
my $TAPS = ( $conf{"Library protocol"} =~ /TAPS/i ) ? 1 : 0;
my $alignonly = ( $conf{"Align-only mode"} =~ /on/i ) ? 1 : 0;
my $CpH       = ( $conf{"Call CpH"} =~ /yes/i ) ? 1 : 0;

print <<HTMLHEADER;
<html>
<head>
<title>Msuite2 Analysis Report</title>
<style type="text/css">
td {
text-align: left;
padding-left: 10px;
}
.multiFrame td {
text-align: center;
font-weight:bold;
}
</style>
</head>
<body>
<h1>Msuite2 Analysis Report</h1>

HTMLHEADER

############################################
print "<h2>Alignment statistics</h2>\n";

## load trim log
open LOG, "$dir/Msuite2.trim.log" or die( "$!" );
my $line = <LOG>;
$line =~ /(\d+)/;
my $total = $1;
$line = <LOG>;	##Dropped : 0
$line =~ /(\d+)/;
my $dropped = $1;
my $trim = $total - $dropped;
close LOG;

## load aligner log
open LOG, "$dir/Msuite2.rmdup.log" or die( "$!" );
my ($waligned, $wdiscard, $wdup) = (0, 0, 0);
my ($caligned, $cdiscard, $cdup) = (0, 0, 0);
my ($cntL, $cntP) = (0, 0);
while( <LOG> ) {
	my @l = split /\t/;	## chr total discard dup

#	$cntL += $l[1]-$l[2]-$l[3] if $l[0]=~/^[cr]hrL/;
	if( $l[0]=~/^[cr]hrL/ ) {
		$cntL += $l[1];
		next;
	}
	if( $l[0]=~/^[cr]hrP/ ) {
		$cntP += $l[1];
		next;
	}
	## report the original read number due to higher dup rate in lambda

	if( $l[0] =~ /^chr/ ) {
		$waligned   += $l[1];
		$wdiscard   += $l[2];
		$wdup += $l[3];
	} else {	# rhrXXX
		$caligned   += $l[1];
		$cdiscard   += $l[2];
		$cdup += $l[3];
	}
}
close LOG;
my $aligned = $waligned + $caligned;
my $discard = $wdiscard + $cdiscard;
my $duplicate = $wdup + $cdup;
my $reported  = $aligned - $discard - $duplicate;
#my $ratioL  = sprintf("%.2f %%", $cntL/($cntL+$aligned) * 100);

print "<table id=\"alignStat\" width=\"75%\">\n",
		"<tr bgcolor=\"$color[0]\"><td width=\"70%\"><b>Total input reads</b></td>",
		"<td width=\"30%\"><b>", digitalize($total), "</b></td></tr>\n",
		"<tr bgcolor=\"$color[1]\"><td><b>After preprocessing</b></td>",
		"<td><b>", digitalize($trim), sprintf(" (%.2f %%)", $trim/$total*100), "</b></td></tr>\n";
my $realTotal = $aligned+$cntL+$cntP;
# print "<tr bgcolor=\"$color[0]\"><td><b>Total aligned reads</b></td>",
# 		"<td><b>", digitalize($realTotal), sprintf(" (%.2f %%)", $realTotal/$trim*100), "</b></td></tr>\n",
# 		"<tr bgcolor=\"$color[0]\"><td>&nbsp;&nbsp;Lambda reads</td>",
# 		"<td>&nbsp;&nbsp;", digitalize($cntL), sprintf(" (%.2f %%)", $cntL/$realTotal*100), "</td></tr>\n",
# 		"<tr bgcolor=\"$color[0]\"><td>&nbsp;&nbsp;pUC19 reads</td>",
# 		"<td>&nbsp;&nbsp;", digitalize($cntP), sprintf(" (%.2f %%)", $cntP/$realTotal*100), "</td></tr>\n",
# 		"<tr bgcolor=\"$color[0]\"><td><b>Non-lambda/pUC19 reads</b></td>",
# 		"<td><b>", digitalize($aligned), sprintf(" (%.2f %%)", $aligned/$realTotal*100), "</b></td></tr>\n",
# 		"<tr bgcolor=\"$color[1]\"><td>&nbsp;&nbsp;Forward chain</td>",
# 		"<td>&nbsp;&nbsp;", digitalize($waligned), sprintf(" (%.2f %%)", $waligned/$aligned*100), "</td></tr>\n",
# 		"<tr bgcolor=\"$color[0]\"><td>&nbsp;&nbsp;Reverse chain</td>",
# 		"<td>&nbsp;&nbsp;", digitalize($caligned), sprintf(" (%.2f %%)", $caligned/$aligned*100), "</td></tr>\n";
print "<tr bgcolor=\"$color[0]\"><td><b>Total aligned reads</b></td>",
        "<td><b>", digitalize($realTotal), 
        ($trim != 0 ? sprintf(" (%.2f %%)", $realTotal/$trim*100) : " (N/A)"), 
        "</b></td></tr>\n",
        "<tr bgcolor=\"$color[0]\"><td>&nbsp;&nbsp;Lambda reads</td>",
        "<td>&nbsp;&nbsp;", digitalize($cntL), 
        ($realTotal != 0 ? sprintf(" (%.2f %%)", $cntL/$realTotal*100) : " (N/A)"), 
        "</td></tr>\n",
        "<tr bgcolor=\"$color[0]\"><td>&nbsp;&nbsp;pUC19 reads</td>",
        "<td>&nbsp;&nbsp;", digitalize($cntP), 
        ($realTotal != 0 ? sprintf(" (%.2f %%)", $cntP/$realTotal*100) : " (N/A)"), 
        "</td></tr>\n",
        "<tr bgcolor=\"$color[0]\"><td><b>Non-lambda/pUC19 reads</b></td>",
        "<td><b>", digitalize($aligned), 
        ($realTotal != 0 ? sprintf(" (%.2f %%)", $aligned/$realTotal*100) : " (N/A)"), 
        "</b></td></tr>\n",
        "<tr bgcolor=\"$color[1]\"><td>&nbsp;&nbsp;Forward chain</td>",
        "<td>&nbsp;&nbsp;", digitalize($waligned), 
        ($aligned != 0 ? sprintf(" (%.2f %%)", $waligned/$aligned*100) : " (N/A)"), 
        "</td></tr>\n",
        "<tr bgcolor=\"$color[0]\"><td>&nbsp;&nbsp;Reverse chain</td>",
        "<td>&nbsp;&nbsp;", digitalize($caligned), 
        ($aligned != 0 ? sprintf(" (%.2f %%)", $caligned/$aligned*100) : " (N/A)"), 
        "</td></tr>\n";

# print "<tr bgcolor=\"$color[1]\"><td><b>Low-quality alignments</b></td>",
# 		"<td><b>", digitalize($discard), sprintf(" (%.2f %%)", $discard/$aligned*100), "</b></td></tr>\n";

# unless( exists $conf{'Keep duplicates'} && $conf{'Keep duplicates'} eq 'Yes' ) {
# print "<tr bgcolor=\"$color[0]\"><td><b>PCR duplicates</b></td>",
# 		"<td><b>", digitalize($duplicate), sprintf(" (%.2f %%)", $duplicate/$aligned*100), "</b></td></tr>\n";
# }
# print "<tr bgcolor=\"$color[1]\"><td><b>Reported alignments</b></td>",
# 		"<td><b>", digitalize($reported), sprintf(" (%.2f %%)", $reported/$aligned*100), "</b></td></tr>\n",
# 	 "</table>\n\n";
print "<tr bgcolor=\"$color[1]\"><td><b>Low-quality alignments</b></td>",
        "<td><b>", digitalize($discard), 
        ($aligned != 0 ? sprintf(" (%.2f %%)", $discard/$aligned*100) : " (N/A)"), 
        "</b></td></tr>\n";

unless (exists $conf{'Keep duplicates'} && $conf{'Keep duplicates'} eq 'Yes') {
    print "<tr bgcolor=\"$color[0]\"><td><b>PCR duplicates</b></td>",
            "<td><b>", digitalize($duplicate), 
            ($aligned != 0 ? sprintf(" (%.2f %%)", $duplicate/$aligned*100) : " (N/A)"), 
            "</b></td></tr>\n";
}

print "<tr bgcolor=\"$color[1]\"><td><b>Reported alignments</b></td>",
        "<td><b>", digitalize($reported), 
        ($aligned != 0 ? sprintf(" (%.2f %%)", $reported/$aligned*100) : " (N/A)"), 
        "</b></td></tr>\n",
        "</table>\n\n";

############################################
unless( $alignonly ) {
print "<h2>Methylation statistics</h2>\n";
## load CpG.meth log
open LOG, "$dir/Msuite2.CpG.meth.log" or die( "$!" );
my ($wC, $wT, $cC, $cT) = ( 0, 0, 0, 0 );
my ($conversionL, $conversionP) = ('NA', 'NA');
while( <LOG> ) {
	next if /^#/;
	chomp;
	my @l = split /\t/;	#chr Total.wC Total.wT Total.cC Total.cT
	if( $l[0] ne 'chrL' && $l[0] ne 'chrP' ) {
		$wC += $l[1];
		$wT += $l[2];
		$cC += $l[3];
		$cT += $l[4];
	} else {	## reads mapped to the lambda/pUC19 genome
		my $totalCT = $l[1]+$l[2]+$l[3]+$l[4];
		if( $totalCT >= $minSpikeIn ) {
			if( $l[0] eq 'chrL' ) {
				$conversionL = sprintf( "%.2f %%", ($l[2]+$l[4])/$totalCT * 100 );
			} else {
				$conversionP = sprintf( "%.2f %%", ($l[2]+$l[4])/$totalCT * 100 );
			}
		}
	}
}
# my ($wm, $cm, $tm);
# if( $TAPS ) {
# 	$wm = sprintf("%.2f", $wT/($wC+$wT)*100);
# 	$cm = sprintf("%.2f", $cT/($cC+$cT)*100);
# 	$tm = sprintf("%.2f", ($wT+$cT)/($wC+$wT+$cC+$cT)*100);
# } else {
# 	$wm = sprintf("%.2f", $wC/($wC+$wT)*100);
# 	$cm = sprintf("%.2f", $cC/($cC+$cT)*100);
# 	$tm = sprintf("%.2f", ($wC+$cC)/($wC+$wT+$cC+$cT)*100);
# }

my ($wm, $cm, $tm);

if ($TAPS) {
    $wm = ($wC + $wT != 0) ? sprintf("%.2f", $wT / ($wC + $wT) * 100) : "N/A";
    $cm = ($cC + $cT != 0) ? sprintf("%.2f", $cT / ($cC + $cT) * 100) : "N/A";
    $tm = ($wC + $wT + $cC + $cT != 0) ? sprintf("%.2f", ($wT + $cT) / ($wC + $wT + $cC + $cT) * 100) : "N/A";
} else {
    $wm = ($wC + $wT != 0) ? sprintf("%.2f", $wC / ($wC + $wT) * 100) : "N/A";
    $cm = ($cC + $cT != 0) ? sprintf("%.2f", $cC / ($cC + $cT) * 100) : "N/A";
    $tm = ($wC + $wT + $cC + $cT != 0) ? sprintf("%.2f", ($wC + $cC) / ($wC + $wT + $cC + $cT) * 100) : "N/A";
}

print "<table id=\"methStat\" width=\"75%\">\n",
		"<tr bgcolor=\"$color[0]\"><td width=\"70%\"><b>Overall CpG methylation density</b></td>" ,
			"<td width=\"30%\"><b>$tm %</b></td></tr>\n",
		"<tr bgcolor=\"$color[1]\"><td>&nbsp;&nbsp;Forward chain</td><td>&nbsp;&nbsp;$wm %</td></tr>\n",
		"<tr bgcolor=\"$color[0]\"><td>&nbsp;&nbsp;Reverse chain</td><td>&nbsp;&nbsp;$cm %</td></tr>\n",
#		"<tr bgcolor=\"$color[1]\"><td><b>Reads mapped to Lambda genome</b></td>",
#			"<td><b>", digitalize($cntL), " ($ratioL %)</b></td></tr>\n",
		"<tr bgcolor=\"$color[0]\"><td><b>C-&gt;T conversion rate (lambda reads)</b></td>",
			"<td><b>$conversionL</b></td></tr>\n",
		"<tr bgcolor=\"$color[0]\"><td><b>C-&gt;T conversion rate (pUC19 reads)</b></td>",
			"<td><b>$conversionP</b></td></tr>\n";

if( $CpH ) {
## load CpH.meth log
open LOG, "$dir/Msuite2.CpH.meth.log" or die( "$!" );
($wC, $wT, $cC, $cT) = ( 0, 0, 0, 0 );
while( <LOG> ) {
	next if /^#/;
	chomp;
	my @l = split /\t/;	#chr Total.wC Total.wT Total.cC Total.cT
	if( $l[0] ne 'chrL' ) {
		$wC += $l[1];
		$wT += $l[2];
		$cC += $l[3];
		$cT += $l[4];
	}
}
my ($wm, $cm, $tm);
if( $TAPS ) {
	$wm = sprintf("%.2f", $wT/($wC+$wT)*100);
	$cm = sprintf("%.2f", $cT/($cC+$cT)*100);
	$tm = sprintf("%.2f", ($wT+$cT)/($wC+$wT+$cC+$cT)*100);
} else {
	$wm = sprintf("%.2f", $wC/($wC+$wT)*100);
	$cm = sprintf("%.2f", $cC/($cC+$cT)*100);
	$tm = sprintf("%.2f", ($wC+$cC)/($wC+$wT+$cC+$cT)*100);
}
print "<tr bgcolor=\"$color[1]\"><td width=\"70%\"><b>Overall CpH methylation density</b></td>" ,
			"<td width=\"30%\"><b>$tm %</b></td></tr>\n",
		"<tr bgcolor=\"$color[0]\"><td>&nbsp;&nbsp;Forward chain</td><td>&nbsp;&nbsp;$wm %</td></tr>\n",
		"<tr bgcolor=\"$color[1]\"><td>&nbsp;&nbsp;Reverse chain</td><td>&nbsp;&nbsp;$cm %</td></tr>\n";
}

print "</table>\n\n";
}
###################################################
print '<h2>Base composition in the sequenced reads</h2>
<table class="multiFrame">
	<tr><td>Read 1 raw sequence</td><td>Read 1 trimmed</td></tr>
	<tr>
		<td><img src="R1.fqstat.png" alt="Base composition in read 1 raw"></td>
		<td><img src="R1.trimmed.fqstat.png" alt="Base composition in read 1 trimmed"></td>
	</tr>
';
if( $pe ) {
	print 
'	<tr><td>Read 2 raw sequence</td><td>Read 2 trimmed</td></tr>
	<tr>
		<td><img src="R2.fqstat.png" alt="Base composition in read 2 raw"></td>
		<td><img src="R2.trimmed.fqstat.png" alt="Base composition in read 2 trimmed"></td>
	</tr>
';
}
print "</table>\n\n";

if( $pe ) {
	my $all_frame = 1;
	++ $all_frame if $cntL;
	++ $all_frame if $cntP;

	unless( $cntL || $cntP ) {	## no Lambda and pUC19
		print '<h2>Fragment size distribution</h2>
	<img src="Msuite2.size.png" alt="fragment size distribution"><br />';
	} else {
		print '<h2>Fragment size distribution (cuttings on head/tail are included)</h2>
<table class="multiFrame">
	<tr><td>Autosomal reads</td>';
		print '<td>Lambda reads</td>' if $cntL >= $minSpikeIn;
		print '<td>pUC19 reads</td>'  if $cntP >= $minSpikeIn;
		print '</tr>
	<tr><td><img src="Msuite2.size.png" alt="size of autosomal reads"></td>';
		print '<td><img src="Msuite2.lambda.size.png" alt="size of lambda reads"></td>' if $cntL >= $minSpikeIn;
		print '<td><img src="Msuite2.pUC19.size.png" alt="size of pUC19 reads"></td>'   if $cntP >= $minSpikeIn;
		print "</tr>\n</table>\n\n";
	}
}

unless( $alignonly ) {
	print
'<h2>Methylation level per chromosome</h2>
	<img src="DNAm.per.chr.png" alt="DNAm.per.chr"><br />
';

if( -s "$dir/Msuite2.report/DNAm.around.TSS.png" ) {
print '<h2>Methylation level around TSS</h2>
	<img src="DNAm.around.TSS.png" alt="Methylation level around TSS"><br />
';}

print '<h2>M-bias plot</h2>
';
if( $pe ) {
	print '<table class="multiFrame">
	<tr><td>Read 1</td><td>Read 2</td></tr>
	<tr><td><img src="R1.mbias.png" alt="M-bias in read 1"></td>
	<td><img src="R2.mbias.png" alt="M-bias in read 2"></td></tr>
</table>
';
} else {
	print
'Read 1<br />
<img src="R1.mbias.png" alt="M-bias in read 1"><br />
';
	}
	print "</ul>\n\n";
}

print "<h2>Analysis Parameters</h2>\n",
		"<table id=\"para\" width=\"80%\">\n",
		"<tr bgcolor=\"#888888\"><td width=\"30%\"><b>Option</b></td><td width=\"70%\"><b>Value</b></td></tr>\n",
		"$parameter</table>\n";

## HTML tail
my ($sec, $min, $hour, $day, $mon, $year, $weekday, $yeardate, $savinglightday) = localtime();
$year+= 1900;
my @month = qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;
$hour = "0$hour" if $hour < 10;
$min  = "0$min"  if $min  < 10;
$sec  = "0$sec"  if $sec  < 10;
$mon = $month[$mon];
my $time = "$hour:$min:$sec, $mon-$day-$year";

print "<HR align=\"left\" width=\"80%\"/>\n",
		"<h4>Generated by <a href=\"$url\" target=\"_blank\">Msuite2</a> (version $ver) on $time.</h4>\n",
		"</body>\n</html>\n";

close OUT;

###############################################################
sub digitalize {
	my $v = shift;

	while($v =~ s/(\d)(\d{3})((:?,\d\d\d)*)$/$1,$2$3/){};
	return $v;
}

