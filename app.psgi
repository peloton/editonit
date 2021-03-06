use strict;
use warnings;
use Tatsumaki::Error;
use Tatsumaki::Application;
use Time::HiRes;

package MessageQueue;
use base qw(Tatsumaki::MessageQueue);

sub append_backlog {
    my($self, @events) = @_;
    $self->backlog([]);
}

package PollHandler;
use base qw(Tatsumaki::Handler);
__PACKAGE__->asynchronous(1);

sub get {
    my ($self) = @_;
    my $client_id = $self->request->param('client_id')
        or Tatsumaki::Error::HTTP->throw(500, "'client_id' needed");
    my $mq = MessageQueue->instance('editonit');
    $mq->poll_once($client_id, sub { $self->on_new_event(@_) });
}

sub on_new_event {
    my ($self, @events) = @_;
    $self->write(\@events);
    $self->finish;
}

package PostHandler;
use base qw(Tatsumaki::Handler);
sub post {
    my ($self) = @_;

    my $v = $self->request->params;
    $v->{time} = scalar Time::HiRes::gettimeofday;
    $v->{address} = $self->request->address;
    my $mq = MessageQueue->instance('editonit');
    $mq->publish($v);
    $self->write({ success => 1 });
}

package GetHandler;
use base qw(Tatsumaki::Handler);

sub get {
    my ($self) = @_;
    $self->render('index.html');
}

package main;
use File::Basename;

my $app = Tatsumaki::Application->new([
    '/editonit/poll' => 'PollHandler',
    '/editonit/post' => 'PostHandler',
    '/(\w+)' => 'GetHandler',
]);

$app->template_path(dirname(__FILE__));
$app->static_path(dirname(__FILE__) . "/static");

return $app;
