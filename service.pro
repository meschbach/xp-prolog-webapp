:- use_module(library(http/thread_httpd)).

service :-
	Port = 8001,
	%
	% Create communication queue
	%
	message_queue_create( Control, [alias(control_queue)] ),
	on_signal( int, _Handler, notify_stop ),!,
	%
	% Start service
	%
	http_server( handle_request, [ port( Port ) ] ), format( "listneing on port ~w~n", [Port]),
	%
	% Termination
	%
	thread_get_message( Control, StopReason ),
	format( "Stopping because: ~w~n", [StopReason] ),
	message_queue_destroy( Control )
	.

%
% Gracefully terminate on a signal
%
notify_stop( Signal ) :-
	message_queue_property( ControlQueue, alias(control_queue) ),
	thread_send_message( ControlQueue, signal(Signal) )
	.

%
% HTTP Request Cycle
%
handle_request( Request ) :-
	respond_not_found( Request )
	.

%
% HTTP response
%
respond_not_found( Request ) :-
	memberchk( path( Path ), Request ),!,
	format( "Status: 404 Not Found" ),
	format( "Content-Type: text/plain~n" ),
	format( "~n" ),
	format( "Resource ~w was not found.~n", Path )
	.
