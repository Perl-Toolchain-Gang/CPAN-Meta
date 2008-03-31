#!/usr/bin/perl

use strict;
use Pod::Html;

pod2html( '--infile' => 'META-spec.pod',
	  '--outfile' => 'META-spec-blead.html',
	);

unlink qw(pod2htmd.tmp pod2htmi.tmp);
