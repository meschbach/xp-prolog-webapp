:- use_module(library(http/thread_httpd)).
:- use_module(library(http/websocket)).

service :-
	Port = 8001,
	%
	% Create communication queue
	%
	message_queue_create( Control, [alias(control_queue)] ),
	on_signal( int, _Handler, notify_stop ),
	!,
	%
	% Start service
	%
	http_server( interpret_request, [ port( Port ) ] ),
	format( "listneing on port ~w~n", [Port]),
	!,
	%
	% Termination
	%
	thread_get_message( Control, StopReason ),!,
	format( "Stopping because: ~w~n", [StopReason] ),!,
	http_stop_server( Port, _ ),!,
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
interpret_request( Request ) :-
	format( user_output, "~w~n", [Request] ),!,
	raw_request( Request )
	.

raw_request( Request ) :-
	memberchk( path( Path ), Request ),
	format( user_output, "Checking websocket ~w~n", [ Path ] ),
	memberchk( connection('Upgrade'), Request ),
	memberchk( upgrade(websocket), Request ),
	format( user_output, "WebSocket request ~n", [] ),
	http_upgrade_to_websocket( new_web_socket( start ), [subprotocols([galaxy])], Request )
	.

raw_request( Request ) :-
	format( user_output, "Checking path ~n", [] ),
	memberchk( path( Path ), Request ),
	interpret_request( Path, Request, Response ),
	respond_with_response( Response, Request ).

%
% Websocket states
%
new_web_socket( State, Websocket ) :-
	format( user_output, "New websocket state ~w:~w~n", [ State, Websocket ] ),!,
	websocket_handler( Websocket, State )
	.

websocket_handler( Websocket, State ) :-
	ws_receive( Websocket, Message ),
	format( user_output, "ws:opcode -> ~w~n", [Message.opcode] ),
	( Message.opcode == close -> format(user_output, "Finished with client ~n", []) ;
		ws_send( Websocket, Message ),
		websocket_handler( Websocket, State )
	) .

%
%  Resource routes
%
interpret_request( '/', _Request, text("Prolog WS Application") ).

respond_with_response( text( Message ), _Request ) :-
	format( "Status: 200 OK" ),
	format( "Content-Type: text/plain~n" ),
	format( "~n~w~n", Message )
	.
respond_with_response( not_found, Request ) :-
	respond_not_found( Request ) .

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
