#!/usr/bin/perl -w

# This script is part of Diogenes.  It is normally run from the
# integrated client/server application, but it can also be run from
# the command line.

# The XML export functionality in this script was developed at the
# request of and with the financial support of the DigiLibLT project.
# The XML output has been designed to harmonize with the subset of TEI
# markup used by that project.  In the default setting, the output
# diverges in a few respects from the norms of DigiLibLT, but a higher
# level of alignment is an option.

use strict;
use warnings;
use Getopt::Std;
use Data::Dumper;
use File::Spec::Functions;
use File::Path;
use File::Spec;
use File::Basename;
use IO::Handle;
use XML::LibXML qw(:libxml);
use File::Which;

use Diogenes::Base qw(%work %author %work_start_block %level_label
                      %database);
use Diogenes::Browser;
use Diogenes::BetaHtml;

my $dirname = 'diogenes-xml';

sub VERSION_MESSAGE {print "xml-export.pl, Diogenes version $Diogenes::Base::Version\n"}

$Getopt::Std::STANDARD_HELP_VERSION = 1;
getopts ('alprho:c:sn:vd');
our ($opt_a, $opt_l, $opt_p, $opt_c, $opt_r, $opt_h, $opt_o, $opt_s, $opt_v, $opt_n);
sub HELP_MESSAGE {
    my $corpora = join ', ', sort values %Diogenes::Base::choices;
    print qq{
xml-export.pl is part of Diogenes; it converts classical texts in the
format develped by the Packard Humanities Institute (PHI) to XML files
conforming to the P5 specification of the Text Encoding Initiative
(TEI).

There are two mandatory switches:

-c abbr   The abberviation of the corpus to be converted; without the -n
          option all authors will be converted.  Valid values are:
          $corpora

-o        Full path to the output directory. If the supplied path contains a
          directory called $dirname, only the path up to that
          directory will be used; if it does not, $dirname will be
          appended to the supplied path. $dirname is created if it
          does not exist, and within it a subdirectory with the name
          of the corpus is created, after deleting any existing
          subdirectory by that name.

The following optional switches are supported:

-v        Verbose info on progress of conversion
-n        Comma-separated list of author numbers to convert
-d        DigiLibLT compatibility; equal to -rpa
-r        Convert book numbers to Roman numerals
-p        Mark paragraphs as milestones rather than divs
-a        Suppress translating indentation into <space> tags
-l        Pretty-print XML using xmllint
-s        Validate output against Relax NG Schema (via Jing;
          requires Java runtime)

};
}

die "Error: specify corpus" unless $opt_c;
my $corpus = $opt_c;
die "Unknown corpus" unless exists $database{$corpus};

die "Error: specify output directory" unless $opt_o;

my ($volume, $directories, $file) = File::Spec->splitpath( $opt_o );
my $path;

if (-e $opt_o and not -d $opt_o) {
    # An existing file in a directory has been specified, so we assume that
    # the directory itself is meant.
    $path = $directories;
}
elsif ($file) {
    $path = File::Spec->catpath('', $directories, $file);
}
else {
    $path = $directories;
}
# If a directory called $dirname is part of the path, use it; if not, append
# $dirname to the given path.
my @dirs = File::Spec->splitdir( $path );
my @newdirs;
for my $dir (@dirs) {
    last if $dir eq $dirname;
    push @newdirs, $dir;
}
push @newdirs, $dirname;
push @newdirs, $corpus;
$path = File::Spec->catpath($volume, File::Spec->catdir(@newdirs), '');

if (-e $path) {
    File::Path->remove_tree($path);
}
File::Path->make_path($path) or die "Could not make dir $path";

my $debug = $opt_v ? 1 : 0;
my $xmlns = 'http://www.tei-c.org/ns/1.0';

my $xml_header=qq{<?xml version="1.0" encoding="UTF-8"?>
<TEI xmlns="$xmlns">
  <teiHeader>
    <fileDesc>
      <titleStmt>
        <title>__TITLE__</title>
        <author>__AUTHOR__</author>
        <respStmt>
          <resp>Automated Conversion to XML</resp>
          <name>Diogenes</name>
        </respStmt>
      </titleStmt>
      <publicationStmt>
        <p>
          This XML text (filename __FILENAME__.xml) was generated by Diogenes (http://d.iogen.es/d) from the __CORPUS__ corpus of classical texts (author number __AUTHNUM__, work number __WORKNUM__), which was once distributed in a very different format on CD-ROM, and which may be subject to licensing restrictions.
        </p>
      </publicationStmt>
      <sourceDesc>
        <p>
          __SOURCE__
        </p>
      </sourceDesc>
    </fileDesc>
  </teiHeader>
  <text>
    <body>
};

my $footer = q{
    </body>
  </text>
</TEI>
};

# Change English labels to conform with the Latinizing usage of DigiLibLT
my %div_translations = (
                        book => 'lib',
                        chapter => 'cap',
                        chap => 'cap',
                        section => 'par',
                        sect => 'par',
                        fragment => 'frag',
                        argument => 'arg',
                        declamation => 'decl',
                        fable => 'fab',
                        letter => 'epist',
                        life => 'vit',
                        name => 'nomen',
                        oration => 'orat',
                        page => 'pag',
                        play => 'op',
                        paradox => 'parad',
                        poem => 'carmen',
                        satire => 'sat',
                        sentence => 'sent',
                        sententia => 'sent',
                        title => 'cap',
                        verse => 'vers',
                        work => 'op',
                        addressee => 'nomen',
                        column => 'col',
);
use charnames qw(:full :short latin greek);
binmode(STDOUT, ":utf8");

my $authtab = File::Spec->catfile( $path, 'authtab.xml' );
open( AUTHTAB, ">$authtab" ) or die "Could not create $authtab\n";
AUTHTAB->autoflush(1);
print AUTHTAB qq{<authtab corpus="$corpus">\n};

my %args;
$args{type} = $corpus;
$args{encoding} = 'UTF-8';
$args{bib_info} = 1;
$args{perseus_links} = 0;

my $query = new Diogenes::Browser(%args);
my ($buf, $i, $auth_name, $real_num, $work_name, $body, $header, $is_verse, $hanging_div);

my @all_auths = sort keys %{ $Diogenes::Base::auths{$corpus} };
if ($opt_n) {
    if ($opt_n =~ m/,/) {
        @all_auths = split /,\s*/, $opt_n;
    }
    else {
        $opt_n =~ s/(\d+)/$1/;
        @all_auths = $opt_n;
    }
}
AUTH: foreach my $auth_num (@all_auths) {
    $real_num = $query->parse_idt ($auth_num);
    $query->{auth_num} = $auth_num;
    $auth_name = $Diogenes::Base::auths{$corpus}{$auth_num};
    my $lang = $Diogenes::Base::lang{$corpus}{$auth_num};
    if ($lang eq 'g') {
        $query->latin_with_greek(\$auth_name);
    }
    $auth_name = strip_formatting($auth_name);
    my $filename_in = $query->{cdrom_dir}.$query->{file_prefix}.
        $auth_num.$query->{txt_suffix};
    my $punct = q{_.;:!?};
    local undef $/;
    print "Converting $auth_name ($auth_num)\n" if $debug;
    open( IN, $filename_in ) or die "Could not open $filename_in\n";
    $buf = <IN>;
    close IN or die "Could not close $filename_in";
    print AUTHTAB qq{<author name="$auth_name" n="$auth_num">\n};
    $i = -1;
    my $body = '';
    my $line = '';
    my $chunk = '';
    my $hanging_div = '';
    my %old_levels = ();
    my %div_labels = ();
    my @relevant_levels = ();
    my @divs;
    my $work_num = 'XXXX';
    my $filename_out = '';
    while ($i++ <= length $buf) {
        my $char = substr ($buf, $i, 1);
        my $code = ord ($char);
        if ($code == hex 'f0' and ord (substr ($buf, ($i+1), 1)) == hex 'fe') {
            # End of file -- close out work
            $chunk .= $line;
            $body .= convert_chunk($chunk, $lang);
            $chunk = '';
            if ($is_verse) {
                $body .= "</l>\n";
            }
            else {
                $body .= "</p>\n";
            }
            $body .= "</div>\n" for (@divs);
            write_xml_file($filename_out, $header.$body.$footer);
            print AUTHTAB "</author>\n";
            next AUTH;
        }
        elsif ($code >> 7) {
            # Close previous line
            if ($hanging_div) {
                # If we come to the end of a line without finding
                # punctuation and we still have an prose div hanging
                # from the previous line, close the div out at start
                # of previous line.  This happens, e.g. when the div
                # was not really hanging as for n="t" title sections.
                if ($chunk =~ m/-\s*$/) {
                    # But first we check to make sure there is no
                    # hyphenation hanging over.  If so, break at a
                    # comma, or, failing that, at the first space in
                    # the line.
                    if ($line =~ m/(.*?),(.*)/) {
                        $chunk .= $1 . ',';
                        $line = $2;
                    }
                    elsif ($line =~ m/(\S+)\s+(.*)/) {
                        $chunk .= $1;
                        $line = $2;
                    }
                    else {
                        warn "No solution: $chunk \n\n$line\n";
                    }
                }
                $body .= convert_chunk($chunk, $lang);
                $chunk = '';
                $body .= $hanging_div;
                $hanging_div = '';
            }
            $chunk .= $line;
            $line = '';
            $query->parse_non_ascii(\$buf, \$i);
            my $new_div = -1;
            if (@relevant_levels and %old_levels) {
            LEVELS: foreach (@relevant_levels) {
                    if (exists $old_levels{$_} and exists $query->{level}{$_} and
                        $old_levels{$_} ne $query->{level}{$_}) {
                        $new_div = $_;
                        last LEVELS;
                    }
                }
            }
            %old_levels = %{ $query->{level} };
            if ($query->{work_num} ne $work_num) {
                # We have a new work
                if ($work_num ne 'XXXX') {
                    # Close out old work unless we have just started this author
                    $body .= convert_chunk($chunk, $lang);
                    $chunk = '';
                    if ($is_verse) {
                        $body .= "</l>\n";
                    }
                    else {
                        $body .= "</p>\n";
                    }
                    $body .= "</div>\n" for (@divs);
                    write_xml_file($filename_out, $header.$body.$footer);
                }
                $work_num = $query->{work_num};

                my %works =  %{ $work{$corpus}{$real_num} };
                $work_name = $works{$work_num};
                if ($lang eq 'g') {
                    $query->latin_with_greek(\$work_name);
                }
                $work_name = strip_formatting($work_name);
                $query->{work_num} = $work_num;
                $filename_out = $corpus.$auth_num.$work_num.'.xml';
                my $source = $query->get_biblio_info($corpus, $auth_num, $work_num);
                if ($lang eq 'g') {
                    $query->latin_with_greek(\$source);
                }
                $source = strip_formatting($source);
                $source =~ s#\s*\n\s*# #g;
                $body = '';
                $hanging_div = '';
                my @time = localtime(time);
                my $year = $time[5];
                $year += 1900;
                my $uppercase_corpus = uc($corpus);
                $header = $xml_header;
                $header =~ s#__AUTHOR__#$auth_name#;
                $header =~ s#__TITLE__#$work_name#;
                $header =~ s#__SOURCE__#$source#;
                $header =~ s#__CORPUS__#$uppercase_corpus#;
                $header =~ s#__AUTHNUM__#$auth_num#;
                $header =~ s#__WORKNUM__#$work_num#;
                $header =~ s#__FILENAME__#$corpus$auth_num$work_num#;
                $header =~ s#__YEAR__#$year#;

                $is_verse = is_work_verse($auth_num, $work_num);
#                 print "$auth_num: $work_num, $is_verse\n" if $debug;
                %div_labels = %{ $level_label{$corpus}{$auth_num}{$work_num} };
                @divs = reverse sort numerically keys %div_labels;
                pop @divs, 1;
                @relevant_levels = @divs;
                push @relevant_levels, 0 if $is_verse;

                for (keys %div_labels) {
                    if (exists $div_translations{$div_labels{$_}}) {
                        $div_labels{$_} =
                            $div_translations{$div_labels{$_}};
                    }
                }
                foreach (@divs) {
                    if ($opt_r and $div_labels{$_} eq 'lib') {
                        $body .= q{<div type="lib" n="}.roman($query->{level}{$_}).qq{">\n};
                    }
                    else {
                        my $n = $query->{level}{$_} || 1; # bug in phi2331025.xml
                        $body .= qq{<div type="$div_labels{$_}" n="$n">\n};
                    }
                }
                if ($is_verse) {
                    $body .= qq{<l n="$query->{level}{0}">};
                }
                else {
                    $body .= q{<p>};
                }
                print AUTHTAB qq{  <work name="$work_name" n="$work_num">\n};
                print AUTHTAB qq{    <div name="$div_labels{$_}"/>\n} for (@divs);
                print AUTHTAB qq{    <verse/>\n} if $is_verse;
            }
            elsif ($new_div >= 0) {
                # We have a new div or line of verse
                my $temp = $is_verse ? "</l>\n" : "</p>\n";
                $temp .= ("</div>\n" x $new_div);

                foreach (reverse 1 .. $new_div) {
                    if ($opt_r and $div_labels{$_} eq 'lib') {
                        $temp .= q{<div type="lib" n="}.roman($query->{level}{$_}).qq{">\n};
                    }
                    else {
                        $temp .= qq{<div type="$div_labels{$_}" n="$query->{level}{$_}">\n};
                    }
                }
                if ($is_verse) {
                    $temp .= qq{<l n="$query->{level}{0}">};
                }
                else {
                    $temp .= q{<p>};
                }
                # We seem to have a prose section which starts in the coming line
                if (((not $is_verse)
                     and ($chunk !~ m#[$punct]\s*$#)
                     and ($chunk =~ m/\S/))
                    # But we need to rule out titles and headings, so
                    # we exclude "t" and where the section is back to 1
                    and (not ($query->{level}{1} and ($query->{level}{1} eq "1"
                                                      or $query->{level}{1} =~ m/t/)))
                    and (not ($query->{level}{2} and
                              ($query->{level}{2} =~ m/t/)))) {

                    $hanging_div = $temp;
                    $chunk .= "\n";
                }
                else {
                    $body .= convert_chunk($chunk, $lang);
                    $chunk = '';
                    $body .= $temp;
                }
            }
            else {
                # We have a line that can be added to the current chunk
                $chunk .= "\n";
            }
        }
        else {
            $line .= $char;
            if ($hanging_div and $char =~ m#[$punct]#) {
                # We have found a suitable punctuation mark to close
                # out a hanging prose div
                $chunk .= $line;
                $line = '';
                $body .= convert_chunk($chunk, $lang);
                $chunk = '';
                $body .= $hanging_div;
                $hanging_div = '';
            }
        }
    }
    # We never get here
}

print AUTHTAB "</authtab>\n";
close(AUTHTAB) or die "Could not close authtab.xml\n";


sub convert_chunk {
    my ($chunk, $lang) = @_;

    # Misplaced full-stop in Hyginus 254.2.  Causes chaos.
#     $chunk =~ s#\[2QVI PIISSIMI FVERVNT\.\]2#\[2QVI PIISSIMI FVERVNT\]2\.#;

    my %acute = (a => "\N{a with acute}", e => "\N{e with acute}", i => "\N{i with acute}", o => "\N{o with acute}", u => "\N{u with acute}",
             A => "\N{A with acute}", E => "\N{E with acute}", I => "\N{I with acute}", O => "\N{O with acute}", U => "\N{U with acute}");
    my %grave = (a => "\N{a with grave}", e => "\N{e with grave}", i => "\N{i with grave}", o => "\N{o with grave}", u => "\N{u with grave}",
             A => "\N{A with grave}", E => "\N{E with grave}", I => "\N{I with grave}", O => "\N{O with grave}", U => "\N{U with grave}");
    my %diaer = (a => "\N{a with diaeresis}", e => "\N{e with diaeresis}", i => "\N{i with diaeresis}", o => "\N{o with diaeresis}", u => "\N{u with diaeresis}",
             A => "\N{A with diaeresis}", E => "\N{E with diaeresis}", I => "\N{I with diaeresis}", O => "\N{O with diaeresis}", U => "\N{U with diaeresis}");
    my %circum = (a => "\N{a with circumflex}", e => "\N{e with circumflex}", i => "\N{i with circumflex}", o => "\N{o with circumflex}", u => "\N{u with circumflex}",
             A => "\N{A with circumflex}", E => "\N{E with circumflex}", I => "\N{I with circumflex}", O => "\N{O with circumflex}", U => "\N{U with circumflex}");
    my %ampersand_dollar = (1 => "bold", 2 => "bold italic", 3 => "italic", 4 => "superscript", 5 => "subscript", 7 => "small capitals", 10 => "small", 11 => "small bold", 13 => "small italic", 20 => "large ", 21 => "large bold", 23 => "large italic");

    # remove hyphenation
    $chunk =~ s#(\S+)\-\s*(?:\@*\d*\s*)\n(\S+)#$1$2\n#g;

    # Greek
    if ($lang eq 'g') {
        $query->greek_with_latin(\$chunk);
    }
    else {
        $query->latin_with_greek(\$chunk);
    }
    # Latin accents
    $chunk =~ s#([aeiouAEIOU])\/#$acute{$1}#g;
    $chunk =~ s#([aeiouAEIOU])\\#$grave{$1};#g;
    $chunk =~ s#([aeiouAEIOU])\=#$circum{$1}#g;
    $chunk =~ s#([aeiouAEIOU])\+#$diaer{$1}#g;

    $chunk =~ s#\[2{43#{43\[2#g; #fix improper nesting in Servius

    # Escape XML reserved chars
    $chunk =~ s#\&#&amp;#g;
    $chunk =~ s#\<#&lt;#g;
    $chunk =~ s#\>#&gt;#g;
    $chunk =~ s#\"\d*#&quot;#g;

    # Speakers in drama: {&7 ... }& {40&7 ... }40&
    $chunk =~ s#\{(?:40)?&amp;7([^}]*)\}(?:40)?#<label type="speaker">$1</label>#g;
    $chunk =~ s#\{40([^}]*)\}40#<label type="speaker">$1</label>#g;
    $chunk =~ s#\{41([^}]*)\}41#<label type="stage-direction">$1</label>#g;

    # Font switching.  Beta does not always nest these properly: e.g
    # "HS &7<ccc&>", so we could try to bring trailing markup inside:
    # $chunk =~
    # s#(?:\$|&amp;)(\d+)(.*)(?:\$|&amp;)\d*((?:\]|\}|&gt;)\d*)#my$tail=$3||'';exists
    # $ampersand_dollar{$1} ? qq{<hi
    # rend="$ampersand_dollar{$1}">$2$tail</hi>} : qq{$2$tail}#ge;
    # but this fails when markup is nested correctly: e.g. "{40&7Phaedria& [2&7Dorias&]2}40
    # Only way to deal with the inconsistency is to throw away font
    # information (which is usually superfluous anyway) when there is
    # any balanced markup inside:
    $chunk =~ s#(?:\$|&amp;)(\d+)([^&{}\[\]]+)(?:\$|&amp;)\d*#exists
        $ampersand_dollar{$1} ? qq{<hi rend="$ampersand_dollar{$1}">$2</hi>} : qq{$2}#ge;

    $chunk =~ s#&amp;\d*##g;
    $chunk =~ s#\$\d*##g;

    # {} titles, marginalia, misc.

    # Fix unbalanced markup
    $chunk =~ s/{2\@{2#10}2/{2#10/g;

    $chunk =~ s#\{1((?:[^\}]|\}[^1])*?)(?:\}1|$)#<head>$1</head>#g;
    $chunk =~ s#\{2((?:[^\}]|\}[^2])*?)(?:\}2|$)#<hi rend="marginalia">$1</hi>#g;
    # Servius
    $chunk =~ s#\{43((?:[^\}]|\}[^4]|\}4[^3])*?)(?:\}43|$)#<seg type="Danielis" rend="italic">$1</seg>#g;
    $chunk =~ s#((?:[^\}]|\}[^4]|\}4[^3])*?)\}43#<seg type="Danielis" rend="italic">$1</seg>#g;

    $chunk =~ s#\{\d+([^\}]+)(?:\}\d+|$)#<head>$1</head>#g;
    # Speakers in e.g. Eclogues: {M.}
    $chunk =~ s#\{([^\}]+)\}#<label type="speaker">$1</label>#g;

#     $chunk =~
#         s#(<hi rend[^>]+>)(.*)<head>(.*)</hi>(.*)</head>#$1$2<head>$3</head>$4</hi>#gs;
#         s#(<hi rend.*?)(<head>.*?)</hi>(.*)</head>#$1$2</head>$3</hi>#gs;
#     $chunk =~
#         s#<head>(.*)(<hi rend[^>]+>)(.*)</head>(.*)</hi>#<head>$1$2$3</hi>$4</head>#gs;
#         s#(<head>.*?)(<hi .*?)</head>(.*?)</hi>#$1foo$2</hi>$3</head>#gs;
#      $chunk =~
#          s#(<hi rend.*?)(<head>.*?)</hi>(.*)</head>#$1$2</head>$3</hi>#gs;




    # # and *#
    $chunk =~ s/\*#(\d+)/$Diogenes::BetaHtml::starhash{$1}/g;
    $chunk =~ s/(?<!&)#(\d+)/$Diogenes::BetaHtml::hash{$1}||'??'/ge;
    $chunk =~ s/(?<!&)#/&#x0374;/g;

    # some punctuation
    $chunk =~ s/_/\ -\ /g;
    $chunk =~ s/!/./g;

    # "inverted dagger", used in Augustus imp., not in Unicode so use
    # normal dagger
    $chunk =~ s/%157/&#134;/g;

    $chunk =~ s#%(\d+)#$Diogenes::BetaHtml::percent{$1}#g;
    # Use more standard glyphs for dagger and double
    $chunk =~ s/%/&#134;/g;
    $chunk =~ s/&#2020;/&#134;/g;
    $chunk =~ s/&#2021;/&#135;/g;

    # @ (whitespace)
    ## Sometimes these appear at the end of a line, to no apparent purpose.
    $chunk =~ s#@+\s*$##g;
    $chunk =~ s#@\d+\s*$##g;
    $chunk =~ s#@+\s*\n#\n#g;
    $chunk =~ s#@\d+\s*\n#\n#g;

    if ($opt_a) {
        $chunk =~ s#@@+\d*#    #g;
        $chunk =~ s#@\d+#  #g;
        $chunk =~ s#@# #g;
    } else {
        $chunk =~ s#@(\d+)#q{<space quantity="}.$1.q{"/>}#ge;
        $chunk =~ s#(@@+)#q{<space quantity="}.(length $1).q{"/>}#ge;
        $chunk =~ s#@#<space/>#g;
        $chunk =~ s#\^(\d+)#q{<space quantity="}.$1.q{"/>}#ge;
        $chunk =~ s#\^#<space/>#g;
    }

    # Not sure if <> are used in PHI texts
    $chunk =~ s#&lt;1(?!\d)((?:(?!\>|$).)+)(?:&gt;1(?!\d))#<hi rend="underline">$1</hi>#gs;
    $chunk =~ s#&lt;6(?!\d)((?:(?!\>|$).)+)(?:&gt;6(?!\d))#<hi rend="superscript">$1</hi>#gs;
    $chunk =~ s#&lt;7(?!\d)((?:(?!\>|$).)+)(?:&gt;7(?!\d))#<hi rend="subscript">$1</hi>#gs;
    $chunk =~ s#&lt;\d*#&lt;#g;
    $chunk =~ s#&gt;\d*#&gt;#g;

    # [] (brackets of all sorts)
    if (0) {
        # This would be to keep typographical markup
        $chunk =~ s#\[(\d+)#$Diogenes::BetaHtml::bra{$1}#g;
        $chunk =~ s#\](\d+)#$Diogenes::BetaHtml::ket{$1}#g;
    }
    else {
        # We try to convert editorial symbols to TEI markup.  This may
        # not always work!

        $chunk =~ s#\[1#(#g;
        $chunk =~ s#\]1#)#g;
        $chunk =~ s#\[2#&lt;#g;
        $chunk =~ s#\]2#&gt;#g;
        $chunk =~ s#\[3#{#g;
        $chunk =~ s#\]3#}#g;
        $chunk =~ s#\[(\d+)#[#g;
        $chunk =~ s#\](\d+)#]#g;

        $chunk =~ s#\[?\.\.\.+\]?#<gap/>#g;
        $chunk =~ s#\[([^\]\n])\]#<del>$1</del>#g;

        $chunk =~ s#&lt;\.\.\.+&gt;#<supplied><gap/></supplied>#g;
        $chunk =~ s#&lt;([^.&><]*)\.\.\.+&gt;#<supplied>$1<gap/></supplied>#g;
        $chunk =~ s#&lt;\.\.\.+([^.&><]*)&gt;#<supplied><gap/>$1</supplied>#g;

        $chunk =~ s#&lt;([^&<>]*)&gt;#<supplied>$1</supplied>#g;
        $chunk =~ s!&#13[45];([^\n])&#13[45];!<unclear>$1</unclear>!g;
        $chunk =~ s!&#13[45];!<unclear/>!g;
    }

    $chunk =~ s#\`##g;

    return $chunk;
}

sub write_xml_file {
    my ($file, $text) = @_;
    if ($debug) {
        my $tmpfile = File::Spec->catfile( $path, $file) . '.tmp';
        open( OUT, ">$tmpfile" ) or die $!;
        print OUT $text;
        close(OUT) or die $!;
    }

    my $xmldoc = post_process_xml($text, $file);

    if ($opt_p) {
        $xmldoc = milestones($xmldoc);
    }

    $text = $xmldoc->toString;

    $text = ad_hoc_fixes($text, $file);

    my $file_path = File::Spec->catfile( $path, $file );
    if ($opt_l) {
        open(LINT, "|xmllint --format - >$file_path") or die "Can't open xmllint: $!";
        print LINT $text;
        close(LINT) or die "Could not close xmllint!\n";
    }
    else {
        open( OUT, ">$file_path" ) or die "Could not create $file\n";
        print OUT $text;
        close(OUT) or die "Could not close $file\n";
    }
    print AUTHTAB "  </work>\n";

    if ($opt_s) {
        print "Validating $file ... ";
        die "Error: Java is required for validation, but java not found"
            unless which 'java';
        # xmllint validation errors can be misleading; jing is better
        # my $ret = `xmllint --noout --relaxng digiliblt.rng $file_path`;
        # my $ret = `java -jar jing.jar -c digiliblt.rnc $file_path`;
        my $ret = `java -jar jing.jar -c tei_all.rnc $file_path`;
        if ($ret) {
            print "Invalid.\n";
            print $ret;
        }
        else {
            print "Valid.\n";
        }
    }
}


sub post_process_xml {
    my $in = shift;
    my $file = shift;

    my $parser = XML::LibXML->new({huge=>1});
    my $xmldoc = $parser->parse_string($in);

    # Change <space>s to @rend.  Best to do this first, and then again
    # last, to take into account changes in between.
    fixup_spaces($xmldoc);

    # Remove all div and l elements with n="t", preserving content;
    # these are just titles and usually have a <head>, so should not
    # appear in a separate div or line.
    foreach my $node ($xmldoc->getElementsByTagName('l'),
                      $xmldoc->getElementsByTagName('div'),) {
        my $n = $node->getAttribute('n');
        if ($n and $n =~ m/^t\d?$/ or $n =~ m/^\d*t$/ or $n =~ m/^\d+t\d+$/) {
            foreach my $child (reverse $node->childNodes) {
                $node->parentNode->insertBefore( $child, $node );
            }
            $node->unbindNode;
        }
    }

    # <head>s often appear inside <p> and <l>, which isn't valid.  So
    # we move the <head> to just before its parent, and then delete
    # the former parent if it has only whitespace content.
    foreach my $node ($xmldoc->getElementsByTagName('head')) {
        my $parent = $node->parentNode;
        if ($parent->nodeName eq 'l' or $parent->nodeName eq 'p') {
            $parent->parentNode->insertBefore($node, $parent);
            $parent->unbindNode unless $parent->textContent =~ m/\S/;
        }
    }

    # When there are two <head>s in immediate succession, it's usually
    # just a line break, so we unify them
    foreach my $node ($xmldoc->getElementsByTagName('head')) {
        my $sib = $node->nextNonBlankSibling;
        if ($sib and $sib->nodeName eq 'head') {
            $node->appendText(' ');
            $node->appendText($sib->textContent);
            $sib->unbindNode;
        }
    }

    # Any remaining <space> within a <head> is just superfluous
    # indentation left over from the unification of a multi-line set
    # of <head>s, so should just be removed.
    foreach my $node ($xmldoc->getElementsByTagName('head')) {
        foreach my $child ($node->childNodes) {
            if ($child->nodeName eq 'space') {
                $child->unbindNode;
            }
        }
    }

    # Some texts have multiple <head>s spread throughout a single
    # <div> or <body>, such as when these represent the titles of
    # works to which a list of fragments have been assigned.  When
    # this happens, we change the <head>s to <label>s, of which we are
    # allowed to have more than one.
    foreach my $node ($xmldoc->getElementsByTagName('head')) {
        my $parent = $node->parentNode;
        foreach my $sibling ($parent->childNodes) {
            if (not $node->isSameNode($sibling) and $sibling->nodeName eq 'head') {
                $sibling->setNodeName('label');
            }
        }
    }

    # Some texts have an EXPLICIT within a <label>, which generally fall
    # after the end of the div, so we tuck them into the end of the
    # preceding div.
    foreach my $node ($xmldoc->getElementsByTagName('label')) {
        if ($node->textContent =~ m/EXPLICIT/) {
            my $sib = $node;
            while ($sib = $sib->previousSibling) {
                if ($sib->nodeName eq 'div') {
                    $sib->appendChild($node);
                    last;
                }
            }
        }
    }

    fixup_spaces($xmldoc);

    return $xmldoc;
}

sub fixup_spaces {
    my $xmldoc = shift;
    # Change <space> to indentation at start of para, line, etc.  Note
    # that this is an imperfect heuristic.  A <space> at the start of
    # a line of verse from a fragmentary papyrus is probably correct,
    # and really should not be converted to indentation.
    foreach my $node ($xmldoc->getElementsByTagName('space')) {
        my $next = $node->nextSibling;
        while ($next and $next->nodeType == XML_TEXT_NODE and $next->data =~ m/^\s*$/s) {
            $next = $next->nextSibling;
        }
        my $parent = $node->parentNode;
        my $quantity = $node->getAttribute('quantity') || '1';
        # If <space> comes right before (allowing whitespace).
        if ($next and $next->nodeName =~ m/^l|p|head|label$/) {
            $next->setAttribute('rend',"indent($quantity)");
            $node->unbindNode;
        } # If <space> comes right after (allowing whitespace).
        elsif ($parent and $parent->nodeName =~ m/^l|p|head|label$/) {
            my $child = $parent->firstChild;
            while ($child->nodeType == XML_TEXT_NODE and $child->data =~ m/^\s*$/s) {
                $child = $child->nextSibling;
            }
            if ($child and $child->isSameNode($node)) {
                $parent->setAttribute('rend',"indent($quantity)");
                $node->unbindNode;
            }
        }
    }
}


sub milestones {
    my $xmldoc = shift;
    # Added this at the request of DigiLibLT.  They prefer paragraph
    # divs to be converted into milestones, so that <div type="par"
    # n="1"> becomes <milestone unit="par" n="1"/> and the
    # higher-level div is contained in just one <p>, with inner <p>s
    # removed. Found this surprisingly tricky, so we do this step by step
    if (not $is_verse) {
         my $xpc = XML::LibXML::XPathContext->new;
         $xpc->registerNs('x', $xmlns);
         # Put a collection of multiple <div type="par">s inside a big
         # <p>
         foreach my $node (
             # Find nodes with a child of at least one <div type="par">
             $xpc->findnodes('//*[x:div/@type="par"]',$xmldoc)) {
             my $new_p = $xmldoc->createElementNS( $xmlns, 'p');

             $new_p->appendText("\n");
             foreach my $child ($node->nonBlankChildNodes) {
                 $new_p->appendChild($child);
             }
             $new_p->appendText("\n");
             $node->appendChild($new_p);
         }

         # Remove all <p>s inside <div type="par">
         foreach my $node (
             $xpc->findnodes('//x:div[@type="par"]/x:p',$xmldoc)) {
             my $parent = $node->parentNode;
             foreach my $child ($node->nonBlankChildNodes) {
                 $parent->appendChild($child);
             }
             $node->unbindNode;
         }
         # Change divs to milestones
         foreach my $node (
             $xpc->findnodes('//x:div[@type="par"]',$xmldoc)) {
             my $mile = $xmldoc->createElementNS($xmlns, 'milestone');
             $mile->setAttribute("unit", "par" );
             $mile->setAttribute("n", $node->getAttribute('n') );
             my $parent = $node->parentNode;
             $parent->appendText("\n");
             $parent->appendChild($mile);
             $parent->appendText("\n");
             foreach my $child ($node->nonBlankChildNodes) {
                 $parent->appendChild($child);
             }
             $node->unbindNode;
         }
         # The foregoing can end up with <head>s inside the new <p>s.
         foreach my $node (
             $xpc->findnodes('//x:p//x:head',$xmldoc)) {
             my $grandparent = $node->parentNode->parentNode;
             $grandparent->insertBefore($node, $node->parentNode);
#              print $grandparent->nodeName;
         }
    }
    return $xmldoc;
}

#=cut
sub ad_hoc_fixes {
    # This is for fixing desperate special cases.
    my $out = shift;
    my $file = shift;

    # Calpurnius Siculus
    if ($file eq 'phi0830001.xml') {
        $out =~ s#\[(<label [^>]*>)#$1\[#g;
        $out =~ s#</label>\]#\]</label>#g;
    }

    # Hyginus Myth
    if ($file eq 'phi1263001.xml') {
        $out =~ s#<label [^>]*><supplied>QVI PIISSIMI FVERVNT\.</supplied></label>\s*<div type="par" n="4">#<div type="par" n="4">\n<label><supplied>QVI PIISSIMI FVERVNT.</supplied></label>#;
    }
    # Porphyry on Horace
    if ($file =~ m/^phi1512/) {
        # Not all of the Sermones have this heading and this one for
        # poem 3 is in the middle of the scholia to poem 2.
        $out =~ s#(<head [^>]*>EGLOGA III</head>.*?</p>\n)#<div type="lemma" n="t">$1</div>#s;
        # Another bizzarely placed heading
        $out =~ s#<head [^>]*>\[DE SATVRA</head>\s*<div type="lemma" n="12a">#<div type="lemma" n="12a"><head>DE SATURA</head>#;
    }

    return $out;
}



sub is_work_verse {
    my ($auth_num, $work_num) = @_;
    # Heuristic to tell prose from verse: a work is verse if its lowest
    # level of markup is "verse" rather than "line", if the author has
    # an "Lyr." in their name or if the ratio of hyphens is very low.
#     print "$query->{auth_num}, $work_num\n";
    my $bottom = $level_label{$corpus}{$auth_num}{$work_num}{0};
    return 1 if $bottom =~ /verse/;
    return 1 if $auth_name =~ /Lyr\./;

    my $start_block = $work_start_block{$corpus}{$query->{auth_num}}{$work_num};
    my $next = $work_num;
    $next++;
    my $end_block = $work_start_block{$corpus}{$query->{auth_num}}{$next} ||
        $start_block + 1;
    my $offset = $start_block << 13;
    my $length = ($end_block - $start_block + 1) << 13;
    my $work = substr $buf, $offset, $length;

    my $hyphens_counter = () = $work =~ m/\-[\x80-\xff]/g;
    return 1 if $hyphens_counter == 0;
    my $lines_counter   = () = $work =~ m/\s[\x80-\xff]/g;
    my $ratio = $lines_counter / $hyphens_counter;
#     print "$work_name: $lines_counter - $hyphens_counter = $ratio\n";
    return 1 if $ratio > 20;
    return 0;
}

sub strip_formatting{
    my $x = shift;
    $query->beta_formatting_to_ascii(\$x);

    # Just in case: remove illegal chars for use in TEI header
    $x =~ s#\&\d*##g;
    $x =~ s#\$\d*##g;
    $x =~ s#\<\d*##g;
    $x =~ s#\>\d*##g;
    $x =~ s#\`# #g;
    $x =~ s#[\x00-\x08\x0b\x0c\x0e-\x1f]##g;
    return $x;
}

sub numerically { $a <=> $b; }

# Copied from the Roman.pm module on CPAN
sub roman {
    my %roman_digit = qw(1 IV 10 XL 100 CD 1000 MMMMMM);
    my @figure = reverse sort keys %roman_digit;
    $roman_digit{$_} = [split(//, $roman_digit{$_}, 2)] foreach @figure;
    my $arg = shift;
    return $arg unless $arg =~ m/^\d+$/;
    return $arg if $arg < 0 or $arg > 4000;
    my ($x, $roman);
    foreach (@figure) {
        my($digit, $i, $v) = (int($arg / $_), @{$roman_digit{$_}});
        if (1 <= $digit and $digit <= 3) {
            $roman .= $i x $digit;
        } elsif ($digit == 4) {
            $roman .= "$i$v";
        } elsif ($digit == 5) {
            $roman .= $v;
        } elsif (6 <= $digit and $digit <= 8) {
            $roman .= $v . $i x ($digit - 5);
        } elsif ($digit == 9) {
            $roman .= "$i$x";
        }
        $arg -= $digit * $_;
        $x = $i;
    }
    return $roman ? lc $roman : $arg;
}
