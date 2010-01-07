package Smolder::Server;
use strict;
use warnings;
use base 'CGI::Application::Server';
use File::Spec::Functions qw(catdir devnull catfile);
use File::Path qw(mkpath);
use Smolder::Conf qw(Port HostName LogFile HtdocsDir DataDir PidFile);
use Smolder::DB;
use Net::Server::PreFork;
use Carp;
$SIG{__DIE__} = \*Carp::confess;

sub new {
    my ($class, %args) = @_;
    my $server = $class->SUPER::new(@_);
    $server->host(HostName);
    $server->port(HostName . ':' . Port);

    $server->entry_points(
        {
            '/'    => 'Smolder::Redirect',
            '/app' => 'Smolder::Dispatch',
            '/js'     => HtdocsDir,
            '/style'  => HtdocsDir,
            '/images' => HtdocsDir,
            '/robots.txt' => HtdocsDir,
        },
    );
    $server->{"__smolder_$_"} = $args{$_} foreach keys %args;
    return $server;
}

sub net_server { 'Net::Server::PreFork' }

sub print_banner {
    my $banner = "Smolder is running on " . HostName . ':' . Port . ", pid $$";
    my $line   = '#' x length $banner;
    print "$line\n$banner\n";
}

sub start {
    my $self = shift;

	if (not -e DataDir) {
		mkpath(DataDir) or die sprintf("Could not create %s: $!", DataDir);
	}

    # do we have a database? If not then create one
    unless (-e Smolder::DB->db_file) {
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
    require Smolder::Control::Developer::Prefs;
    require Smolder::Control::Projects;
    require Smolder::Control::Graphs;
    require Smolder::Control::Public;
    require Smolder::Control::Public::Auth;
    require Smolder::Redirect;

    my @net_server_args = (pid_file => PidFile);
    if( $self->{__smolder_daemon} ) {
        return $self->background(@net_server_args);
    } else {
        return $self->run(@net_server_args);
    }
}

sub run {
    my $self = shift;

    # send warnings to our logs
    my $log_file = LogFile || devnull();
    my $ok = open(STDERR, '>>', $log_file);
    if (!$ok) {
        warn "Could not open logfile $log_file for appending: $!";
        exit(1);
    }

    $self->SUPER::run(@_);
}

1;
