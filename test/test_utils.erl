%%%=============================================================================
%%% @copyright (C) 1999-2013, Erlang Solutions Ltd
%%% @author Diana Corbacho <diana.corbacho@erlang-solutions.com>
%%% @doc
%%% @end
%%%=============================================================================
-module(test_utils).

-export([start_listener/1,
	 start_listener/1,
	 send_message/1,
	 stop_listener/1]).

start_listener({fragmented, Msg}) ->
    random:seed(erlang:now()),
    start_listener(Msg, fun fragmented_user_response/1);
start_listener(Msg) ->
    start_listener(Msg, fun user_response/1).

start_listener(Msg, Fun) ->
    {ok, Listener, LS, Port} = webserver:start(gen_tcp, [Fun(Msg)]),
    {ok, Socket} = gen_tcp:connect("127.0.0.1", Port, [binary, {packet, raw},
						       {nodelay, true},
						       {reuseaddr, true},
						       {active, false}], 5000),
    {Listener, LS, Socket}.

send_message(Socket) ->
    gen_tcp:send(Socket, message()).


send_fragmented_message(Module, Socket, L) when is_list(L) ->
    send_fragmented_message(Module, Socket, list_to_binary(L));
send_fragmented_message(_, _, <<>>) ->
    ok;
send_fragmented_message(Module, Socket, Msg) ->
    Length = erlang:byte_size(Msg),
    R = random(Length),
    Bin = binary:part(Msg, 0, R),
    Module:send(Socket, Bin),
    send_fragmented_message(Module, Socket, binary:part(Msg, R, erlang:byte_size(Msg) - R)).

random(Length) when Length =< 5 ->
    random:uniform(Length);
random(_Length) ->
    random:uniform(5).

user_response(Message) ->
    fun(Module, Socket, _, _, _) ->
	    Module:send(Socket, Message)
    end.

fragmented_user_response(Message) ->
    fun(Module, Socket, _, _, _) ->
	    send_fragmented_message(Module, Socket, Message)
    end.

message() ->
    <<"GET /blabla HTTP/1.1\r\nhost: 127.0.0.1:5050\r\nuser-agent: Cow\r\nAccept: */*\r\n\r\n">>.

stop_listener({Listener, LS, Socket}) ->
    unlink(Listener),
    (catch exit(Listener, kill)),
    gen_tcp:close(LS),
    gen_tcp:close(Socket).