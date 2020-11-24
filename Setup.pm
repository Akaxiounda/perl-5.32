#!/usr/bin/perl -w

package  Setup;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(create_internet_shortcuts create_shortcuts create_file_assoc);

use lib q(.);
use File::Path qw( mkpath );
use File::Spec::Functions qw(catfile);
use File::Basename qw(basename);
use Config;
use Cwd qw(cwd);

use Win32;
use Win32::API;
use Win32::Shortcut;
use Win32::TieRegistry;

BEGIN { Win32::Unicode::InternetShortcut->CoInitialize(); }
END { Win32::Unicode::InternetShortcut->CoUninitialize(); }

our $VERSION           = '0.02';
my $SHCNE_ASSOCCHANGED = 0x8_000_000;
my $SCNF_FLUSH         = 0x1000;

my $ORGANIZATION = 'ActiveState';
my $PROJECT      = 'perl-5.32';
my $NAMESPACE    = "$ORGANIZATION/$PROJECT";
my $PLATFORM_URL = "https://platform.activestate.com/$NAMESPACE";

# Import Win32 function: `void SHChangeNotify(int eventId, int flags, IntPtr item1, IntPtr item2)`

my $SHChangeNotify = Win32::API::More->new( 'shell32', 'SHChangeNotify', 'iiPP', 'V' );
if ( not defined $SHChangeNotify ) {
    die "Can't import SHChangeNotify: ${^E}\n";
}

sub update_win32_shell {
    $SHChangeNotify->Call( $SHCNE_ASSOCCHANGED, $SCNF_FLUSH, 0, 0 );
    return;
}

sub desktop_dir_path {
    return Win32::GetFolderPath(Win32::CSIDL_DESKTOPDIRECTORY());
}

sub start_menu_path {
    return Win32::GetFolderPath(Win32::CSIDL_STARTMENU());
}

sub create_internet_shortcut {
    my $target   = shift;
    my $icon     = shift;
    my $linkPath = shift;

    if ( -e $lnkPath ) {
        unlink $lnkPath;
    }

    #print "Creating internet shortcut: $lnkPath -> $target\n";
    my $link = Win32::Unicode::InternetShortcut->new;
    $link->save($lnkPath, $target);
    $link->load($lnkPath);

    ($link->{target} eq $target) || die "Not the same url\n";

    return;
}

sub create_shortcut {
    my $target   = shift;
    my $icon     = shift;
    my $linkPath = shift;
    my $location = shift;

    if ( -e $lnkPath ) {
        unlink $lnkPath;
    }

    #print "Creating application shortcut: $lnkPath -> $target\n";
    my $LINK = Win32::Shortcut->new();
    $LINK->{'Path'} = $target;
    $LINK->{'IconLocation'}     = $icon;
    $LINK->{'IconNumber'}       = 0;
    $LINK->{'WorkingDirectory'} = $location;
    $LINK->Save($lnkPath);
    $LINK->Close();

    return;
}

sub create_internet_shortcuts {
    my $target  = $PLATFORM_URL;
    my $icon    = q();
    my $lnkName = "$NAMESPACE Web.url";

    my $start_menu_base = catfile(start_menu_path(), $ORGANIZATION);
    mkpath($start_menu_base);

    my $startLnkPath = catfile($start_menu_base, $lnkName);
    create_internet_shortcut($target, $icon, $startLnkPath);

    my $dsktpLnkPath = catfile(desktop_dir_path(), $lnkName);
    create_internet_shortcut($target, $icon, $dsktpLnkPath);

    return;
}

sub create_shortcuts {
    my $target  = "cmd /c state activate";
    my $icon    = q();
    my $lnkName = "$NAMESPACE CLI.lnk";

    my $start_menu_base = catfile(start_menu_path(), $ORGANIZATION);
    mkpath($start_menu_base);

    my $startLnkPath = catfile($start_menu_base, $lnkName);
    create_shortcut($target, $icon, $startLnkPath, cwd);

    my $dsktpLnkPath = catfile(desktop_dir_path(), $lnkName);
    create_shortcut($target, $icon, $dsktpLnkPath, cwd);

    return;
}

sub create_file_assoc {
    my $cmd       = $Config{perlpath};
    my $assocsRef = ['.pl', '.perl'];

    my $cmd_name = basename($cmd);
    my $prog_id  = "$ORGANIZATION.${cmd_name}";

    # file type description
    $Registry->{"CUser\\Software\\Classes\\${prog_id}\\"} = {
        "\\" => "$cmd_name document",
        "shell\\" => {
            "open\\" => {
                "command\\" => {
                    "\\" => "$cmd %1 %*"
                }
            }
        }
    };

    foreach (@$assocsRef) {
        #print "Creating file association: $_: $prog_id\n";
        $Registry->{"CUser\\Software\\Classes\\$_\\"} = {"" => $prog_id};
    }

    update_win32_shell();

    return;
}

1;
