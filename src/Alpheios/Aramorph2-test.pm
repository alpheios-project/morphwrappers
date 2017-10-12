#!/usr/bin/perl -w
################################################################################
# Buckwalter Arabic Morphological Analyzer Version 2.0
# Portions (c) 2002-2004 QAMUS LLC (www.qamus.org), 
# (c) 2002-2004 Trustees of the University of Pennsylvania 
# 
# LDC USER AGREEMENT
# 
# Use of this version of the Buckwalter Arabic Morphological Analyzer Version 2
# distributed by the Linguistic Data Consortium (LDC) of the University of 
# Pennsylvania is governed by the following terms: 
# 
# This User Agreement is provided by the Linguistic Data Consortium as a 
# condition of accepting the databases named or described herein. 
# 
# This Agreement describes the terms between User/User's Research Group and 
# Linguistic Data Consortium (LDC), in which User will receive material, as 
# specified below, from LDC. The terms of this Agreement supercede the terms of 
# any previous Membership Agreement in regard to the Buckwalter Arabic 
# Morphological Analyzer Version 2.
# 
# Under this agreement User will receive one or more CD-ROM discs, DVDs, 
# electronic files or other media as appropriate, containing linguistic tools, 
# speech, video, and/or text data. User agrees to use the material received 
# under this agreement only for non-commercial linguistic education and research
# purposes. Unless explicitly permitted herein, User shall have no right to 
# copy, redistribute, transmit, publish or otherwise use the LDC Databases for 
# any other purpose and User further agrees not to disclose, copy, or 
# re-distribute the material to others outside of User's research group. 
# 
# Government use, including any use within or among government organizations and
# use by government contractors to produce or evaluate resources and 
# technologies for government use, is permitted under this license.
# 
# Organizations interested in licensing the Buckwalter Arabic Morphological 
# Analyzer Version 2 for commercial use should contact: 
# 
#    QAMUS LLC 
#    448 South 48th St. 
#    Philadelphia, PA 19143 
#    ATTN: Tim Buckwalter 
#    email: license@qamus.org
# 
# Except for Government use as specified above, commercial uses of this corpus 
# include, but are not limited to, imbedded use of the Analyzer, Analyzer 
# methods, Analyzer derived works, Analyzer output data, algorithms, lexicons, 
# and downloaded data in a commercial product or a fee for service project; 
# use of the Analyzer, Analyzer methods, Analyzer derived works, Analyzer 
# output data, algorithms, and downloaded data to create or develop a 
# commercial product or perform a fee for service project; use of Analyzer, 
# Analyzer methods, Analyzer derived works, Analyzer output data, algorithms, 
# lexicons, and downloaded data as a development tool to measure performance of
# a commercial product or work product developed on a fee for service basis; 
# redistribution of Analyzer, Analyzer methods, Analyzer derived works, Analyzer 
# output data, algorithms, lexicons and downloaded data to any third party for 
# imbedding in a commercial product or fee for service project, for deriving a 
# commercial product or fee for service project, or for measuring the 
# performance of a commercial product or fee for service project.
# 
# USER ACKNOWLEDGES AND AGREES THAT "CORPORA RECEIVED" ARE PROVIDED ON AN "AS-IS"
# BASIS AND THAT LDC, ITS HOST INSTITUTION THE UNIVERSITY OF PENNSYLVANIA, AND 
# ITS DATA PROVIDERS AND CORPUS AUTHORS MAKE NO REPRESENTATIONS OR WARRANTIES OF 
# ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO IMPLIED WARRANTIES 
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR CONFORMITY WITH 
# WHATEVER DOCUMENTATION IS PROVIDED. IN NO EVENT SHALL LDC, ITS HOST 
# INSTITUTION, DATA PROVIDORS OR CORPUS AUTHORS BE LIABLE FOR SPECIAL, DIRECT, 
# INDIRECT, CONSEQUENTIAL, PUNITIVE, INCIDENTAL OR OTHER DAMAGES, LOSSES, COSTS, 
# CHARGES, CLAIMS, DEMANDS, FEES OR EXPENSES OF ANY NATURE OR KIND ARISING IN ANY
# WAY FROM THE FURNISHING OF OR USER'S USE OF THE CORPORA RECEIVED. 
# 
#
################################################################################
# usage: 
# perl -w AraMorph.pl < infile.txt > outfile.xml
# were "infile" is the input text in Arabic Windows encoding (Windows-1256) 
# and "outfile.xml" is the output text in UTF-8 encoding with morphology analyses 
# and POS tags. The list of "not found" items is written to filename "nf" and 
# related statistics are written to STDERR. For example:
# 
# perl -w AraMorph.pl < infile.txt > outfile.xml
# loading dictPrefixes ... 548 entries
# loading dictStems ...  40219 lemmas and 78839 entries
# loading dictSuffixes ... 906 entries
# reading input line 28
# tokens: 67  -- not found (types): 1 (1.49253731343284%)

################################################################################
#
#
# Modified by Michael Gursky and Bridget Almas for use in the Alpheios project, 2010.
# - Support only command line input
# - Support only Buckwalter input and output
# - Create Alpheios-compatible XML output
# - enable as CGI/mod_perl
package Alpheios::Aramorph2;

use strict;
use Data::Dumper;

use Apache2::RequestRec ();
use Apache2::RequestIO ();
  
use Apache2::Const -compile => qw(OK);


use Encode qw/encode decode/; 
binmode STDOUT, ":utf8"; # Perl 5.8.0

# Package Globals
my $version = "2.0-alpheios";
my $basedir;
set_basedir();

my $suppress = 1;
my (%pos_hash,%hash_AB,%hash_AC,%hash_BC,%prefix_hash,%stem_hash,%suffix_hash,%alt_chars,%pofs_order);
my (%seen_lookup_words,%not_found);
my $usage = <<"END_OF_USAGE";
    AraMorph: Arabic morphological analyzer and POS tagger, v. $version

    Usage:   perl $0 [options] <word1> [<word2> ...]

    Options:
      &h, &help             Print usage
      &v, &version          Print version ($version)
END_OF_USAGE

# Registered as PerlPostConfigHandler, this method should only be called
# once per parent HTTPD process. It initializes the dictionary data which is shared by all child 
# HTTPD Processes and threads.
sub post_config {
    # create morphology mappings
    %pos_hash = load_map($basedir . "tablePos");

    # load 3 compatibility tables (load these first so when we 
    # load the lexicons we can check for 
    # undeclared $cat values) -- this has not been implemented yet
    
    # compatibility table for prefix-stem combinations    (AB)
    %hash_AB = load_table($basedir . "tableab"); 

    # compatibility table for prefix-suffix combinations  (AC)
    %hash_AC = load_table($basedir . "tableac"); 

    # compatibility table for stem-suffix combinations    (BC)
    %hash_BC = load_table($basedir . "tablebc"); 

    # load 3 lexicons
    %prefix_hash = load_dict($basedir . "dictprefixes"); # dict of prefixes (A)
    %stem_hash   = load_dict($basedir . "dictstems");    # dict of stems    (B)
    %suffix_hash = load_dict($basedir . "dictsuffixes"); # dict of suffixes (C)

    # characters which don't have a buckwalter equivalent and their mappings
    %alt_chars = load_map($basedir . "equivalences",1); # map of equivalences

     # order for part of speech
     %pofs_order = 
     (
         'verb' => 10,
         'noun' => 9,
         'proper noun' => 8,
         '*' => 0
     );
     return Apache2::Const::OK;
}

sub handler {
    my $r = shift; # Apache Request object
    my $querystring = $r->args() || q{};
    my %params;
    foreach my $arg (split /[&;]/, $querystring) {
        my ($name,$value) = $arg =~ /^(.+)=(.*)$/;
        push @{$params{$name}},$value;
    }
 
    if ($params{'h'} || $params{'help'} || $params{'v'} || $params{'version'})
    {
        $r->content_type("text/plain");
         print $usage;
         return Apache2::Const::OK;
    }
    $r->content_type("text/xml");
    print '<?xml version="1.0"?>', "\n";

    # copyright notice for output
    print '<!-- Output of Buckwalter Arabic Morphological Analyzer Version 2.0 -->', "\n";
    print '<!-- Portions (c) 2002-2004 QAMUS LLC (www.qamus.org),              -->', "\n";
    print '<!-- (c) 2002-2004 Trustees of the University of Pennsylvania       -->', "\n";
    print '<!-- Modifications (c) 2010 The Alpheios Project, Ltd.              -->', "\n";



    #open (NOTFOUND, ">>nf") || die "cannot open file: $!";
    #binmode NOTFOUND, ":utf8"; # Perl 5.8.0
    my $not_found_cnt = 0; 
    my $tokens = 0;
    print "<words>\n";
    foreach my $word (@{$params{'word'}})
    {

        $word =~ s/%([0-9a-fA-F][0-9a-fA-F])/chr(hex($1))/eg; 
	# use replacements for untransliterated unicode chars
	foreach my $char (keys %alt_chars)
	{
            my $uc = chr(hex($char));
    	    if ($word =~ /$uc/) {
                my @alts = split /,/, $alt_chars{$char};
                # for all but the first alternative, add a new word
                # to the list of words
                # TODO - this should really look for multiple instances
                # of the char to be replaces, and create a new word for
                # each permutation of all the possibilities
                my $num = scalar @alts;
                for (my $i=1; $i<$num; $i++)
                {
                    print STDERR "i = $i\n";
                    my $alt_char = $alts[$i];
                    my $new_word = $word;
    	            $new_word =~ s/$uc/$alt_char/g;
                    push @{$params{'word'}}, $new_word;
                    print STDERR "Added new word replacing $uc with $alt_char\n" ;
                }
    	        $word =~ s/$uc/$alts[0]/g;
                print STDERR "Replaced $uc with $alts[0]\n" 
            }
	}
	print STDERR "got <", $word, ">\n" unless $suppress;

	my @tokens = tokenize($word); # returns a list of tokens (one line at a time)
	foreach my $token (@tokens) {
	    # (1) process Arabic words
	    if ($token =~ m/[0-9PJRG'|>&<\{\}AbptvjHxd*rzs\$SDTZEg_fqklmnhwYyFNKaui~o]/) 
	    { 
		# it's an Arabic word
		my $lookup_word = get_lookup($token); # returns the Arabic string without vowels/diacritics
		my $xml_variant;
		if ( $lookup_word eq "" ) 
		{ # input was one or more zero-width diacritics not attached to any char (i.e., a typo)
		    $xml_variant = $token; 
		    print "  <variant>$xml_variant\n"; 
		    print "    <solution>\n";
		    print "      <voc>$xml_variant</voc>\n";
		    print "      <pos>$xml_variant/NOUN</pos>\n";
		    print "      <gloss>[loose diacritic(s)]</gloss>\n";
		    print "    </solution>\n";
		    print "  </variant>\n"; 
		}
		else {
		    $lookup_word =~ s/Y(?=([^']))/y/g; # Y is always y unless /(Y$|Y'$)/ (we convert /Y'$/ to /\}/ and /y'/ later)
		    my $not_found = 1; 
		    $tokens++; #$types{$lookup_word}++; 
		    unless (exists($seen_lookup_words{$lookup_word}) ) { 
			my @variants = get_variants($lookup_word); # always returns at least one: the initial $lookup_word
			foreach my $variant (@variants) 
			{
			    $xml_variant = $variant; # get a copy to modify and print to XML output file
			    $xml_variant = convert_string($variant);
                            my $solution = analyze($variant);
			    if ( scalar keys %{$solution})
			    { # if the variant has 1 or more solutions
				$not_found = 0; 
			        $seen_lookup_words{$lookup_word} .= 
                                    make_xml($solution,$xml_variant);
			    }
                            my $no_solution = analyze_notfound($variant);
			    if ( scalar keys %{$no_solution})
			    { # if variant has 1 or more "no_solutions"
			        $seen_lookup_words{$lookup_word} .= 
                                    make_xml($no_solution,$xml_variant);
			    }
			}  # end foreach variant
			if ( $not_found == 1 ) 
			{ 
			    $seen_lookup_words{$lookup_word} .= qq!<unknown xml:lang="ara">$xml_variant</unknown>\n!;
			    $not_found{$token} = 1;
			}
		    } # end processing of unseen words
		    print "$seen_lookup_words{$lookup_word}"; 
		} # end if not just diactric
	    } # end if arabic word
	} #end foreach token
    }#end foreach arg
    print '</words>', "\n";

    my $not_found_percent;
    if ( $not_found_cnt > 0 ) {
	$not_found_percent = $not_found_cnt * 100 / $tokens;
    }
    else { $not_found_percent = 0 }

    print STDERR "\ntokens: $tokens  -- not found (types): $not_found_cnt ";
    print STDERR "($not_found_percent\%)";
    return Apache2::Const::OK
}

# ============================
sub analyze { # returns a list of 1 or more solutions

   my $this_word = shift @_; 
   my $cnt = 0;
   my @segmented = segmentword($this_word); # get a list of valid segmentations
   my $solved = {};
   foreach my $segmentation (@segmented) {
      my ($prefix,$stem,$suffix) = split ("\t",$segmentation); #print $segmentation, "\n";
      if (exists($prefix_hash{$prefix})) {
         if (exists($stem_hash{$stem})) {
            if (exists($suffix_hash{$suffix})) {
               # all 3 components exist in their respective lexicons, but are they compatible? (check the $cat pairs)
               foreach my $prefix_value (@{$prefix_hash{$prefix}}) {
                  my ($prefix, $voc_a, $cat_a, $gloss_a, $pos_a) = split (/\t/, $prefix_value);
                  foreach my $stem_value (@{$stem_hash{$stem}}) {
                     my ($stem, $voc_b, $cat_b, $gloss_b, $pos_b, $lemmaID) = split (/\t/, $stem_value);

                     if ( exists($hash_AB{"$cat_a"." "."$cat_b"}) ) {
                        foreach my $suffix_value (@{$suffix_hash{$suffix}}) {
                           my ($suffix, $voc_c, $cat_c, $gloss_c, $pos_c) = split (/\t/, $suffix_value);
                           $voc_c =~ s/&/&amp;/g; $voc_c =~ s/>/&gt;/g; $voc_c =~ s/</&lt;/g; 
                           $pos_c =~ s/&/&amp;/g; $pos_c =~ s/>/&gt;/g; $pos_c =~ s/</&lt;/g; 
                           if ( exists($hash_AC{"$cat_a"." "."$cat_c"}) ) {
                              if ( exists($hash_BC{"$cat_b"." "."$cat_c"}) ) {
                                 my $voc_str = "$voc_a+$voc_b+$voc_c"; 
                                 $voc_str =~ s/^((wa|fa)?(bi|ka)?Al)\+([tvd\*rzs\$SDTZln])/$1$4~/; # moon letters
                                 $voc_str =~ s/^((wa|fa)?lil)\+([tvd\*rzs\$SDTZln])/$1$3~/; # moon letters
                                 $voc_str =~ s/A\+a([pt])/A$1/; # e.g.: Al+HayA+ap
                                 $voc_str =~ s/\{/A/g; 
                                 $voc_str =~ s/\+//g; 
                                 #$voc_str = "$voc_a$voc_b$voc_c"; $voc_str =~ s/Aa/A/; # e.g.: AlHayAap
                                 my $pos_str = "$pos_a+$pos_b+$pos_c"; $pos_str =~ s/^\+//; $pos_str =~ s/\+$//; 
                                 my $gloss_str = "$gloss_a + $gloss_b + $gloss_c"; $gloss_str =~ s/^\s*\+\s*//; $gloss_str =~ s/\s*\+\s*$//; 
                                 add_solution(
                                     solution => $solved,
                                     lemmaID => $lemmaID,
                                     voc_a => $voc_a,
                                     voc_b => $voc_b,
                                     voc_c => $voc_c,
                                     pos_a => $pos_a,
                                     pos_b => $pos_b,
                                     pos_c => $pos_c,
                                     gloss_a => $gloss_a,
                                     gloss_b => $gloss_b,
                                     gloss_c => $gloss_c
                                 );
                              }
                           }
                        }
                     }
                  }
               }# end foreach $prefix_value
            }
         }# end if (exists($stem_hash{$stem}))
      }
   }# end foreach $segmentation
   return $solved;
}
# ==============================================================
sub analyze_notfound { # returns a list of 1 or more "solutions" based on wildcard stem

   my $this_word = shift @_; 
   my $solved = {};
   my $cnt = 0;
   my @segmented = segmentword($this_word); # get a list of valid segmentations
   foreach my $segmentation (@segmented) {
      my ($prefix,$stem,$suffix) = split ("\t",$segmentation); #print $segmentation, "\n";
      my $stemX = $stem; $stemX =~ s/./X/g;
      $stem  =~ s/&/&amp;/g; $stem  =~ s/>/&gt;/g; $stem  =~ s/</&lt;/g; 
      if (exists($prefix_hash{$prefix})) {
         if (exists($stem_hash{$stemX})) {
            if (exists($suffix_hash{$suffix})) {
               # all 3 components exist in their respective lexicons, but are they compatible? (check the $cat pairs)
               foreach my $prefix_value (@{$prefix_hash{$prefix}}) {
                  my ($prefix, $voc_a, $cat_a, $gloss_a, $pos_a) = split (/\t/, $prefix_value);
                  $voc_a =~ s/&/&amp;/g; $voc_a =~ s/>/&gt;/g; $voc_a =~ s/</&lt;/g; 
                  $pos_a =~ s/&/&amp;/g; $pos_a =~ s/>/&gt;/g; $pos_a =~ s/</&lt;/g;
                  foreach my $stem_value (@{$stem_hash{$stemX}}) {
                     my ($stemX, $voc_b, $cat_b, $gloss_b, $pos_b, $lemmaID) = split (/\t/, $stem_value);
                     $pos_b =~ s|X+/|$stem/|; #$lemmaID =~ s|X+|$stem|;
                     if ( exists($hash_AB{"$cat_a"." "."$cat_b"}) ) {
                        foreach my $suffix_value (@{$suffix_hash{$suffix}}) {
                           my ($suffix, $voc_c, $cat_c, $gloss_c, $pos_c) = split (/\t/, $suffix_value);
                           if ( exists($hash_AC{"$cat_a"." "."$cat_c"}) ) {
                              if ( exists($hash_BC{"$cat_b"." "."$cat_c"}) ) {
                                 my $voc_str = "$voc_a$stem$voc_c"; $voc_str =~ s/Aa/A/; # e.g.: AlHayAap
                                 my $pos_str = "$pos_a+$pos_b+$pos_c"; $pos_str =~ s/^\+//; $pos_str =~ s/\+$//; 
                                 my $gloss_str = "$gloss_a + $gloss_b + $gloss_c"; $gloss_str =~ s/^\s*\+\s*//; $gloss_str =~ s/\s*\+\s*$//; 
                                 add_solution(
                                     solution => $solved,
                                     lemmaID => $lemmaID,
                                     voc_a => $voc_a,
                                     voc_b => $voc_b,
                                     voc_c => $voc_c,
                                     pos_a => $pos_a,
                                     pos_b => $pos_b,
                                     pos_c => $pos_c,
                                     gloss_a => $gloss_a,
                                     gloss_b => $gloss_b,
                                     gloss_c => $gloss_c
                                 ); 
                              }
                           }
                        }
                     }
                  }
               }# end foreach $prefix_value
            }
         }# end $stem_hash
      }
   }# end foreach $segmentation
   return $solved;
}

# ===========================================            
sub get_variants { # builds a list of orthographic variants

   my $lookup_word = shift @_; 
   my @variants = ();
   my %seen_variants = ();
   my $str = '';

   push (@variants, $lookup_word); 
   $seen_variants{$lookup_word} = 1; # we don't want any duplicates

   # loop through the list of variants and add more variants if necessary
   my @list = @variants; 
   foreach my $item (@list) {
      $str = $item;
      if ($str =~ s/Y'$/}/) { 
         unless ( exists $seen_variants{$str} ) {
            push (@variants,$str);
            $seen_variants{$str} = 1;
         }
      }
   }

   @list = @variants; 
   foreach my $item (@list) {
      $str = $item;
      if ($str =~ s/w'/&/) { 
         unless ( exists $seen_variants{$str} ) {
            push (@variants,$str);
            $seen_variants{$str} = 1;
         }
      }
   }

   @list = @variants; 
   foreach my $item (@list) {
      $str = $item;
      if ($str =~ s/y'$/}/) { 
         unless ( exists $seen_variants{$str} ) {
            push (@variants,$str);
            $seen_variants{$str} = 1;
         }
      }
   }

   @list = @variants; 
   foreach my $item (@list) {
      $str = $item;
      if ($str =~ s/y$/Y/) { 
         unless ( exists $seen_variants{$str} ) {
            push (@variants,$str);
            $seen_variants{$str} = 1;
         }
      }
   }

   @list = @variants; 
   foreach my $item (@list) {
      $str = $item;
      if ($str =~ s/Y/y/g) { 
         unless ( exists $seen_variants{$str} ) {
            push (@variants,$str);
            $seen_variants{$str} = 1;
         }
      }
   }

   @list = @variants; 
   foreach my $item (@list) {
      $str = $item;
      if ($str =~ s/h$/p/) { 
         unless ( exists $seen_variants{$str} ) {
            push (@variants,$str);
            $seen_variants{$str} = 1;
         }
      }
   }

   @list = @variants; 
   foreach my $item (@list) {
      $str = $item;
      if ($str =~ s/p$/h/) { 
         unless ( exists $seen_variants{$str} ) {
            push (@variants,$str);
            $seen_variants{$str} = 1;
         }
      }
   }

   return @variants;
   
}
# ============================
sub tokenize_orig { # returns a list of tokens (from Win-1256 encoding)
   my $line = shift @_; chomp($line);
   $line =~ s/\xA0/ /g; # convert NBSP to SP
   $line =~ s/\s+/ /g; $line =~ s/^\s+//; $line =~ s/\s+$//; # minimize and trim white space
   $line =~ s/([^\xC8\xCA-\xCE\xD3-\xD6\xD8-\xDF\xE1\xE3-\xE5\xEC\xED])\xDC/$1\xB1/g; 
   my @tokens = split (/([^\x81\x8D\x8E\x90\xC1-\xD6\xD8-\xDF\xE1\xE3-\xE6\xEC-\xED\xF0-\xF3\xF5\xF6\xF8\xFA]+)/,$line);
   return @tokens;
}

sub tokenize { # returns a list of tokens from Buckwalter transliteration
    my $line = shift @_;
    chomp($line);
    $line =~ s/^\s+//; $line =~ s/\s+$//; $line =~ s/\s+/ /g; # remove or minimize white space
    my @tokens = split (/([^PJRG'|>&<{}AbptvjHxd*rzs\$SDTZEg_fqklmnhwYyFNKaui~o]+)/,$line);
    return @tokens;
}

# ============================
sub tokenize_nonArabic { # tokenize non-Arabic strings by splitting them on white space
   my $nonArabic = shift @_;
   $nonArabic =~ s/^\s+//; $nonArabic =~ s/\s+$//; # remove leading & trailing space
   my @nonArabictokens = split (/\s+/, $nonArabic);
   return @nonArabictokens;
}
# ================================
sub get_lookup { # creates a lookup version of the Arabic input string (removes diacritics; transliterates)
   my $input_str = shift @_;
   my $tmp_word = $input_str; # we need to modify the input string for lookup
   $tmp_word =~ s/_//g; #remove kashida/taTwiyl (U+640)
   $tmp_word =~ s/FA/AF/g;  # change -FA to canonical -AF 
   $tmp_word =~ s/AF/A!/g;  # change -AF temporarily to -A!
   $tmp_word =~ s/[FNKaui~o]//g;  # remove all vowels/diacritics
   $tmp_word =~ s/A!/AF/g;  # restore -AF from temporary -A!
   #$tmp_word =~ tr/\x81\x8D\x8E\x90\xA1\xBA\xBF\xC1\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xCB\xCC\xCD\xCE\xCF\xD0\xD1\xD2\xD3\xD4\xD5\xD6\xD8\xD9\xDA\xDB\xDC\xDD\xDE\xDF\xE1\xE3\xE4\xE5\xE6\xEC\xED\xF0\xF1\xF2\xF3\xF5\xF6\xF8\xFA/PJRG,;?'|>&<}AbptvjHxd*rzs\$SDTZEg_fqklmnhwYyFNKaui~o/; # convert to transliteration
   return $tmp_word;
}
# ============================
sub segmentword { # returns a list of valid segmentations

   my $str = shift @_;
   my @segmented = ();
   my $prefix_len = 0;
   my $suffix_len = 0;
   my $str_len = length($str);

   while ( $prefix_len <= 4 ) {
      my $prefix = substr($str, 0, $prefix_len);
      my $stem_len = ($str_len - $prefix_len); 
      my $suffix_len = 0;
      while (($stem_len >= 1) and ($suffix_len <= 6)) {
         my $stem   = substr($str, $prefix_len, $stem_len);
         my $suffix = substr($str, ($prefix_len + $stem_len), $suffix_len);
         push (@segmented, "$prefix\t$stem\t$suffix");
         $stem_len--;
         $suffix_len++;
      }
      $prefix_len++;
   }
   return @segmented;

}

# ==============================================================
sub load_dict { # loads a dict into a hash table where the key is $entry and its value is a list (each $entry can have multiple values)

   my %temp_hash = (); 
   my %seen;
   my $lemmas;
   my $entries = 0; 
   my $lemmaID = "";
   my $filename = shift @_;
   open (IN, $filename) || die "cannot open: $!";
   print STDERR "loading $filename ...";
   while (<IN>) {
      if (m/^;; /) {  
         $lemmaID = $'; 
         chomp($lemmaID);
         if ( exists($seen{$lemmaID}) ) { 
            die "lemmaID $lemmaID in $filename (line $.) isn't unique\n" ; # lemmaID's must be unique
         }
         else { 
            $seen{$lemmaID} = 1; 
	    $lemmas++;
         } 
      } 
      elsif (m/^;/) {  } # comment
      else {
         chomp(); $entries++;
	 my $POS;
	 my $gloss;
         # a little error-checking won't hurt:
         my $trcnt = tr/\t/\t/; if ($trcnt != 3) { die "entry in $filename (line $.) doesn't have 4 fields (3 tabs)\n" };
         my ($entry, $voc, $cat, $glossPOS) = split (/\t/, $_); # get the $entry for use as key
         # two ways to get the POS info:
         # (1) explicitly, by extracting it from the gloss field:
         if ($glossPOS =~ m!<pos>(.+?)</pos>!) {
            $POS = $1; # extract $POS from $glossPOS
            $gloss = $glossPOS; # we clean up the $gloss later (see below)
         }
         # (2) by deduction: use the $cat (and sometimes the $voc and $gloss) to deduce the appropriate POS
         else {
            $gloss = $glossPOS; # we need the $gloss to guess proper names
            if     ($cat  =~ m/^(Pref-0|Suff-0)$/) {$POS = ""} # null prefix or suffix
            elsif  ($cat  =~ m/^F/)          {$POS = "$voc/FUNC_WORD"}
            elsif  ($cat  =~ m/^IV.*?_Pass/) {$POS = "$voc/VERB_IMPERFECT_PASS"} # added 12/18/2002
            elsif  ($cat  =~ m/^IV/)         {$POS = "$voc/VERB_IMPERFECT"}
            elsif  ($cat  =~ m/^PV.*?_Pass/) {$POS = "$voc/VERB_PERFECT_PASS"} # added 12/18/2002
            elsif  ($cat  =~ m/^PV/)         {$POS = "$voc/VERB_PERFECT"}
            elsif  ($cat  =~ m/^CV/)         {$POS = "$voc/VERB_IMPERATIVE"}
            elsif (($cat  =~ m/^N/)
              and ($gloss =~ m/^[A-Z]/))     {$POS = "$voc/NOUN_PROP"} # educated guess (99% correct)
            elsif (($cat  =~ m/^N/)
              and  ($voc  =~ m/iy~$/))       {$POS = "$voc/NOUN"} # (was NOUN_ADJ: some of these are really ADJ's and need to be tagged manually)
            elsif  ($cat  =~ m/^N/)          {$POS = "$voc/NOUN"}
            else                             { die "no POS can be deduced in $filename (line $.)"; }; 
         }

         # clean up the gloss: remove POS info and extra space
         $gloss =~ s!<pos>.+?</pos>!!; $gloss =~ s/\s+$//; $gloss =~ s!;!/!g;

         # create list of orthographic variants for the entry:
         my @entry_forms = ($entry);
         my $temp_entry = $entry; # get a temporary working copy of the $entry
         if ( $temp_entry =~ s/^[>|<\{]/A/ ) { # stem begins with hamza
            push ( @entry_forms, $temp_entry ); 
         }
         # now load the variant forms
         foreach my $entry_form (@entry_forms) {
            push ( @{ $temp_hash{$entry_form} }, "$entry_form\t$voc\t$cat\t$gloss\t$POS\t$lemmaID") ;
         }
      }
   }
   close IN;
   print STDERR "  $lemmas lemmas and" unless ($lemmaID eq "");
   print STDERR " $entries entries \n";
   return %temp_hash;
}

# ==============================================================
sub load_table { # loads a compatibility table into a hash table

   my %temp_hash = ();
   my $filename = shift @_;
   open (IN, $filename) || die "cannot open: $!";
   while (<IN>) {
      unless ( m/^;/ ) {
         chomp();
         s/^\s+//; s/\s+$//; s/\s+/ /g; # remove or minimize white space
         $temp_hash{$_} = 1;
      }
   }
   close IN;
   return %temp_hash;

}
# ==============================================================
# convert unsafe characters to XML entities
sub convert_string
{
  my $word = shift @_;
  $word =~ s/&/&amp;/g;     #do this first so we don't convert &gt; &lt;
  $word =~ s/>/&gt;/g;
  $word =~ s/</&lt;/g;
  return $word;
}

# ==============================================================
sub load_map { # loads a key/value table into a hash table

   my %temp_hash = ();
   my $filename = shift @_;
   my $allow_multiple = shift @_;
   open (IN, $filename) || die "cannot open $filename: $!";
   while (<IN>) {
      unless ( m/^;/ ) {
         chomp();
         s/^\s+//; s/\s+$//; # remove leading/trailing white space
         my @tokens = split("\t", $_);
         if (exists $temp_hash{$tokens[0]} && $allow_multiple) {
             $temp_hash{$tokens[0]} = join ",", ($temp_hash{$tokens[0]}, $tokens[1]);
         } else {
             $temp_hash{$tokens[0]} = $tokens[1];
         }
      }
   }
   close IN;
   return %temp_hash;
}

sub add_solution {
    my %a_args = (
        solution => {},
        lemmaID => '',
        voc_a => '',
        voc_b => '',
        voc_c => '',
        pos_a => '',
        pos_b => '',
        pos_c => '',
        gloss_a => '',
        gloss_b => '',
        gloss_c => '',
        @_);
    my $hdwd = $a_args{lemmaID} ? convert_string($a_args{lemmaID}) : "-";
    my $pref = $a_args{voc_a} ? convert_string($a_args{voc_a}) : "-";
    my $stem = $a_args{voc_b} ? convert_string($a_args{voc_b}) : "_";
    my $suff = $a_args{voc_c} ? convert_string($a_args{voc_c}) : "-";
                                     
    unless (exists $a_args{solution}{$hdwd}) { $a_args{solution}{$hdwd} = {};}
    unless (exists $a_args{solution}{$hdwd}{$stem}) { $a_args{solution}{$hdwd}{$stem} = {};}
    # dissect morphology
    my $POS = '-';
    if ($a_args{pos_b}) 
    { 
        $POS = $a_args{pos_b};
        $POS =~ s/^[^+\/]*\///;
        $POS = $pos_hash{$POS};
    } 
    unless ($POS) { $POS = '-'};
    unless (exists $a_args{solution}{$hdwd}{$stem}{$POS}) { 
        $a_args{solution}{$hdwd}{$stem}{$POS} = { gloss => [], infl => {} } ;
    }
    # remove <text>/ preceding actual parts of speech
    my $morph = $a_args{pos_a}. $a_args{pos_b}. $a_args{pos_c};
    $morph =~ s/^[^+\/]*\///;
    $morph =~ s/\+[^+\/]*\//\+/g;
    $a_args{solution}{$hdwd}{$stem}{$POS}{infl}{$pref} = {} 
        unless exists $a_args{solution}{$hdwd}{$stem}{$POS}{infl}{$pref};
    $a_args{solution}{$hdwd}{$stem}{$POS}{infl}{$pref}{$suff} = { morph => [], gloss => []}
        unless exists $a_args{solution}{$hdwd}{$stem}{$POS}{infl}{$pref}{$suff};
    push @{$a_args{solution}{$hdwd}{$stem}{$POS}{infl}{$pref}{$suff}{morph}}, 
        $morph;
                             
    my $gloss = "";
    if ($a_args{gloss_a}) { $gloss .= "$a_args{gloss_a} + "; }
    if ($a_args{gloss_b}) { $gloss .= $a_args{gloss_b}; }
    if ($a_args{gloss_c}) { $gloss .= " + $a_args{gloss_c}"; }
    if ($a_args{gloss_b} && 
        ! (grep { $_ eq convert_string($a_args{gloss_b}) } 
                @{$a_args{solution}{$hdwd}{$stem}{$POS}{gloss}} )) {
          push @{$a_args{solution}{$hdwd}{$stem}{$POS}{gloss}}, 
            convert_string($a_args{gloss_b}) 
    }
    if ( $gloss &&  
         !(grep {$_ eq convert_string($gloss) }
                @{$a_args{solution}{$hdwd}{$stem}{$POS}{infl}{$pref}{$suff}{gloss}})) {
        push @{$a_args{solution}{$hdwd}{$stem}{$POS}{infl}{$pref}{$suff}{gloss}}, 
            convert_string($gloss);
    }
    return;
}

sub make_xml {
    my ($solution,$xml_variant) = @_;
    my $xml = '';
    foreach my $hdwd (keys %$solution) {
        next if $hdwd =~ /^X.+(_\d+)?$/;
        $xml .= qq!<word>\n  <form xml:lang="ara">$xml_variant</form>\n!;
        foreach my $stem (keys %{$solution->{$hdwd}}) {
            foreach my $pofs (keys %{$solution->{$hdwd}{$stem}}) {
                my $order = $pofs_order{$pofs} || $pofs_order{'*'};
	        $xml .= qq!  <entry>\n!;
                foreach my $pref (keys %{$solution->{$hdwd}{$stem}{$pofs}{infl}}) {
                   foreach my $suff (keys %{$solution->{$hdwd}{$stem}{$pofs}{infl}{$pref}}) {
		       $xml .= qq!      <infl>\n!;
		       $xml .= qq!        <term xml:lang="ara">!;
		       $xml .= qq!<pref>$pref</pref>! unless $pref eq '-';
		       $xml .= qq!<stem>$stem</stem>! unless $stem eq '-';
		       $xml .= qq!<suff>$suff</suff>! unless $suff eq '-';
		       $xml .= qq!</term>\n!;
	               $xml .= qq!          <pofs order="$order">$pofs</pofs>\n! unless $pofs eq '-';
                       foreach my $morph (@{$solution->{$hdwd}{$stem}{$pofs}{infl}{$pref}{$suff}{morph}}) {
		           $xml .= qq!\n        <note>@{[convert_string($morph)]}</note>\n!;
                       }
                       foreach my $gloss (@{$solution->{$hdwd}{$stem}{$pofs}{infl}{$pref}{$suff}{gloss}}) {
		          $xml .= qq!\n        <xmpl>@{[convert_string($gloss)]}</xmpl>\n!;
                       }
		       $xml .= "    </infl>\n";
                   } # end suff
               } # end pref
			   my ($hdwd_clean,$note,$sense);
			   if ($hdwd =~ /-u[iw]?(_\d+)?$/)
			   {
				   ($hdwd_clean,$note,$sense) = $hdwd =~ /^(.*?)(-u[iw]?)(_\d+)?$/;
                                   $note = "[$hdwd]";
                                   $hdwd_clean .= $sense;
			   }
			   else
			   {
				   $hdwd_clean = $hdwd;
			   }
	       $xml .= qq!    <dict><hdwd xml:lang="ara">$hdwd_clean</hdwd>\n!
                   unless $hdwd eq '-'; 
               # TODO - figure out how to display the -u[iw]
               #$xml .= qq!            <note>$note</note>\n! if $note;
	       $xml .= qq!          <pofs order="$order">$pofs</pofs>\n! unless $pofs eq '-';
               $xml .= qq!    </dict>\n!;
               foreach my $gloss (@{$solution->{$hdwd}{$stem}{$pofs}{gloss}}) { 
	           $xml .= qq!    <mean>$gloss</mean>!;
               }  
               $xml .= qq!  </entry>\n!;
            }  # end pofs 
        } # end stem 
        $xml .= qq!</word>\n!;
    } # end hdwd
    return $xml;
}

sub set_basedir {
    my $dir = shift;
    unless ($dir) 
    {
        $dir = "/var/www/perl/Alpheios/bama2/";
    }
    $basedir = $dir;
}
1;
