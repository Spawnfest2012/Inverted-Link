%% Copyright 2012 Alexander Tchitchigin
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%       http://www.apache.org/licenses/LICENSE-2.0
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and limitations under the License.

-module(fotoncms).
-author('Andy Gross <andy@basho.com>').
-author('Justin Sheehy <justin@@basho.com>').
-author('Alexander Tchitchigin <at@fosslabs.ru>').
-export([start/0, start_link/0, stop/0]).

ensure_started(App) ->
    case application:start(App) of
        ok ->
            ok;
        {error, {already_started, App}} ->
            ok
    end.

%% @spec start_link() -> {ok,Pid::pid()}
%% @doc Starts the app for inclusion in a supervisor tree
start_link() ->
    ensure_started(inets),
    ensure_started(crypto),
    ensure_started(bcrypt),
    ensure_started(mongodb),
    ensure_started(mochiweb),
    application:set_env(webmachine, webmachine_logger_module, 
                        webmachine_logger),
    ensure_started(webmachine),
    fotoncms_sup:start_link().

%% @spec start() -> ok
%% @doc Start the fotoncms server.
start() ->
    ensure_started(inets),
    ensure_started(crypto),
    ensure_started(bcrypt),
    ensure_started(mongodb),
    ensure_started(mochiweb),
    application:set_env(webmachine, webmachine_logger_module, 
                        webmachine_logger),
    ensure_started(webmachine),
    application:start(fotoncms).

%% @spec stop() -> ok
%% @doc Stop the fotoncms server.
stop() ->
    Res = application:stop(fotoncms),
    application:stop(webmachine),
    application:stop(mochiweb),
    application:stop(mongodb),
    application:stop(bcrypt),
    application:stop(crypto),
    application:stop(inets),
    Res.
