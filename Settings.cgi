#!/usr/bin/perl -w
use strict;
use Diogenes::Base;
use CGI qw(:standard);
use CGI::Carp 'fatalsToBrowser';
use Data::Dumper;    
use Cwd;
use File::Spec;
$| = 1;

sub generate_user_id {
    # Create a 11 character random string (Perl cookbook)
    my @chars = ( "A" .. "Z", "a" .. "z", 0 .. 9 );
    my $user_id = join("", @chars[ map { rand @chars } (1 .. 11) ]);
    my $user_dir = File::Spec->catdir($Diogenes::Base::config_dir_base, $user_id);
    if (-e $user_dir) {
        print STDERR "Odd -- dir for $user_id already exists;\n";
        return generate_user_id();
    }
    return $user_id;
};

my $q = $Diogenes_Daemon::params ? new CGI($Diogenes_Daemon::params) : new CGI;
# my $q = new CGI;
 
# Don't bother with cookies when the browser runs the server -- this
# allows the cli tool to pick up the settings made with the web tool.
my $d;
if ($ENV{'Diogenes-Browser'})
{
    print $q->header(-type=>"text/html; charset=utf-8");
    $d = new Diogenes::Base(-type => 'none');
}
else
{
    my $user = $q->cookie('userID');
    unless ($user) {
        $user = generate_user_id();
    }
    my $cookie = $q->cookie(-name=>'userID',
                            -value=>$user,
                            -expires=>'+20y');
    print $q->header(-type=>"text/html; charset=utf-8", -cookie=>$cookie);
    $d = new Diogenes::Base(-type => 'none', -user =>$user);
}

my $rcfile = $d->{auto_config};
my $config_file = $d->{user_config};

my @fields = qw(context cgi_default_encoding perseus_show cgi_font browse_lines 
                input_encoding tlg_dir phi_dir ddp_dir) ;

my %perseus_labels = (popup => "Pop up a new window",
                      split => "Split window",
                      newpage => "Show in new page",
                      full => "Show in same page");

my $begin_comment = "
## This file is automatically generated -- do not edit it by hand.
## Instead, use a file called diogenes.config in this directory to
## record configuration options that will not be overwritten or
## overridden by these settings. \n";

my $perl_ver = sprintf "%vd\n", $^V;
my $xulrunner_ver = $ENV{'Xulrunner-version'};

my $version_info = 
"Diogenes version: $Diogenes::Base::Version
<br>Perl version: $perl_ver";
if ($xulrunner_ver) {
    $version_info .= "<br>Xulrunner (Mozilla) version: $xulrunner_ver";
}
$version_info .= '<br>Operating System: '. $^O;

my $display_splash = sub
{

    print $q->start_html(-title=>'Diogenes Settings Page',
                         -bgcolor=>'#FFFFFF'), 
    $q->start_form,
    '<center>',
    $q->h1('Your Diogenes Settings'),

#         $q->h2('You can change some of your settings here:'),
        $q->table
        (
         $q->Tr
         (
          $q->th({align=>'right'}, 'Greek input mode:'),
          $q->td($q->popup_menu(-name=>'input_encoding',
                                -Values=>['Unicode', 'Perseus-style', 'BETA code'],
                                -Default=>$d->{input_encoding}))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'Greek output encoding:'),
          $q->td($q->popup_menu(-name=>'cgi_default_encoding',
                                -Values=>[$d->get_encodings],
                                -Default=>$d->{cgi_default_encoding}))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'How to present Perseus data:'),
          $q->td($q->popup_menu(-name=>'perseus_show',
                                -values=>[keys %perseus_labels],
                                -labels=>\%perseus_labels,
                                -default=>$d->{perseus_show}))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'Font for user interface:'),
          $q->td($q->textfield(-name=>'cgi_font',
                               -size=>40,
                               -maxlength=>100,
                               -Default=>$d->{cgi_font}))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'Amount of context to show in searches:'),
          $q->td($q->popup_menu(-name=>'context',
                                -Values=>\@Diogenes::Base::contexts,
                                -Default=>$d->{context}))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'Number of lines to show in browser:'),
          $q->td($q->popup_menu(-name=>'browse_lines',
                                -Values=>[$d->{browse_lines}, 1..4, map {$_ * 5} (1 .. 20)],
                                -Default=>$d->{browse_lines}))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'The location of the TLG database:'),
          $q->td($q->textfield( -name=>'tlg_dir',
                                -size=>40,
                                -maxlength=>100,
                                -Default=>$d->{tlg_dir}))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'The location of the PHI database:'),
          $q->td($q->textfield( -name=>'phi_dir',
                                -size=>40,
                                -maxlength=>100,
                                -Default=>$d->{phi_dir}))
         ),
         $q->Tr
         (
          $q->th({align=>'right'}, 'The location of the DDP database:'),
          $q->td($q->textfield( -name=>'ddp_dir',
                                -size=>40,
                                -maxlength=>100,
                                -Default=>$d->{ddp_dir}))
         ),
        ),
          $q->p('To enable new settings, click below'),
          $q->table($q->Tr($q->td(
                               $q->submit(-Value=>'Save these settings',
                                          -name=>'Write'),
                           )));
    # Don't suggest that remote users edit server config files
    if ($ENV{'Diogenes-Browser'}) {
        print
            $q->hr,
            $q->h2('For experts'),
            $q->p('A number of other, more obscure settings for Diogenes can be specified.
You can add these manually to a configuration file: ', 
                  "<br> $config_file <br> To view all settings currently in effect, click here."),
            $q->table($q->Tr($q->td(
                                 $q->submit(-Value=>'Show all current settings',
                                            -name=>'Show'),
                             )));
    }
    print
        $q->hr,
        $q->h2('Version information'),
        $q->p($version_info),
        $q->p('<a href="Diogenes.cgi">Click here to return to Diogenes.</a>'),
        

          '</center>',
          $q->end_form,
          $q->end_html;                  
};

my $display_current = sub
{
    print '<html><head><title>Diogenes Settings</title></head>
	 <body>';
    
    print '<h3>Current configuration settings for Diogenes:</h3>';
    
    my $init = new Diogenes::Base(type => 'none');
    my $dump = Data::Dumper->new([$init], [qw(Diogenes Object)]);
    $dump->Quotekeys(0);
    $dump->Maxdepth(1);
    my $out = $dump->Dump;
    
    $out=~s/&/&amp;/g;
    $out=~s/\"/&quot;/g;
    $out=~s/>/&gt;/g;
    $out=~s/</&lt;/g;                            
    
    my @out = split /\n/, $out;
    $out[0] = $out[-1] = '';
    
    print '<pre>';
    print (join "\n", sort @out);
    print '</pre></body></html>';
};

my $write_changes = sub
{
    my $user_dir = File::Spec->catdir($Diogenes::Base::config_dir_base, $d->{user});
    unless (-e $user_dir) {
        mkdir $user_dir or die $!;
    }

    my $file = $begin_comment;
    for my $field (@fields)
    {	
        $file .= "$field ".'"'.$q->param($field).'"'."\n";
    }
    
    open RC, ">$rcfile" or die "Can't open $rcfile: $!\n";
    print RC $file;
    close RC or die "Can't close $rcfile: $!\n";

    print $q->start_html(-title=>'Settings confirmed',
                         -bgcolor=>'#FFFFFF'), 
    $q->center(
        $q->h1('Settings changed'),
        $q->p("Your new settings are now in effect, and have been written to this file:<br>$rcfile"),
        $q->p('<a href="Diogenes.cgi">Click here to continue.</a>')),
    $q->end_html;                  
};


if ($q->param('Show'))
{
    $display_current->();
}
elsif ($q->param('Write'))
{
    $write_changes->();
}
else
{
    $display_splash->();
}

