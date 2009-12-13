package Smolder::Server;
use strict;
use warnings;
use base 'CGI::Application::Server';
use File::Spec::Functions qw(catdir devnull);
use Smolder::Conf qw(Port HostName LogFile HtdocsDir);
use Smolder::DB;

sub new {
    my ($class, %args) = @_;
    my $server = $class->SUPER::new(@_);
    $server->host(HostName);
    $server->port(Port);

    $server->entry_points(
        {
            '/'    => 'Smolder::Redirect',
            '/app' => 'Smolder::Dispatch',
            '/js'     => HtdocsDir,
            '/style'  => HtdocsDir,
            '/images' => HtdocsDir,
        },
    );
    $server->{"__smolder_$_"} = $args{$_} foreach keys %args;
    return $server;
}

sub print_banner {
    my $banner = "Smolder is running on " . HostName . ':' . Port;
    my $line   = '#' x length $banner;
    print "$line\n$banner\n";
}

sub start {
    my $self = shift;

    unless (-e Smolder::DB->db_file) {

        # do we have a database? If not then create one
        Smolder::DB->create_database;
    } else {

        # upgrade if we need to
        require Smolder::Upgrade;
        Smolder::Upgrade->new->upgrade();
    }

    # preload our perl modules
    require Smolder::Dispatch;
    require Smolder::Control;
    require Smolder::Control::Admin;
    require Smolder::Control::Admin::Developers;
    require Smolder::Control::Admin::Projects;
    require Smolder::Control::Developer;
    require Smolder::Control::Developer::Graphs;
    require Smolder::Control::Developer::Prefs;
    require Smolder::Control::Developer::Projects;
    require Smolder::Control::Public;
    require Smolder::Control::Public::Auth;
    require Smolder::Control::Public::Graphs;
    require Smolder::Control::Public::Projects;
    require Smolder::Redirect;

    # send warnings to our logs
    my $log_file = LogFile || devnull();
    my $ok = open(STDERR, '>>', $log_file);
    if (!$ok) {
        warn "Could not open logfile $log_file for appending: $!";
        exit(1);
    }

    if( $self->{__smolder_daemon} ) {
        return $self->background();
    } else {
        return $self->run();
    }
}

1;
