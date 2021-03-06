%% Copyright 2012 Alexander Tchitchigin
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%       http://www.apache.org/licenses/LICENSE-2.0
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and limitations under the License.

-module(fotoncms_feed_resource).
-author('Alexander Tchitchigin <at@fosslabs.ru>').
-export([init/1, to_json/2, to_text/2, content_types_provided/2,
         is_authorized/2]).

-include_lib("webmachine/include/webmachine.hrl").


init([]) -> {ok, undefined}.
    
content_types_provided(ReqData, Context) ->
    {[{"application/json", to_json}, {"text/javascript", to_json}, {"text/plain", to_text}], ReqData, Context}.

to_text(ReqData, Context) ->
    Callback = wrq:get_qs_value("callback", ReqData),
    PathInfo = wrq:path_info(ReqData),
    Account = dict:fetch(account, PathInfo),
    Feed = dict:fetch(feed, PathInfo),
    Conn = fotoncms_dal:connect(),
    {ok, Posts} = fotoncms_dal:get_feed(Conn, Account, Feed),
    fotoncms_dal:disconnect(Conn),
    Items = lists:map(fun(Doc) -> mongo_to_mochijson2(bson:exclude(['_id'], Doc)) end, Posts),
    Json = {struct, [{account, list_to_binary(Account)},
		     {feed, list_to_binary(Feed)},
		     {items, Items}]},
    Data = mochijson2:encode(Json),
    {Body, ReqData1} = case Callback of
			   undefined ->
			       NewRD = wrq:set_resp_header("Content-Type", "application/json", ReqData),
			       {Data, NewRD};
			   _ ->
			       Jsonp = io_lib:format("~s(~s);", [Callback, iolist_to_binary(Data)]),
			       NewRD = wrq:set_resp_header("Content-Type", "text/javascript", ReqData),
			       {Jsonp, NewRD}
		       end,
    {Body, ReqData1, Context}.

to_json(ReqData, Context) ->
    {Body, _RD, Ctx2} = to_text(ReqData, Context),
    {Body, ReqData, Ctx2}.

is_authorized(ReqData, Context) ->
    case wrq:disp_path(ReqData) of
        "authdemo" -> 
            case wrq:get_req_header("authorization", ReqData) of
                "Basic "++Base64 ->
                    Str = base64:mime_decode_to_string(Base64),
                    case string:tokens(Str, ":") of
                        ["authdemo", "demo1"] ->
                            {true, ReqData, Context};
                        _ ->
                            {"Basic realm=webmachine", ReqData, Context}
                    end;
                _ ->
                    {"Basic realm=webmachine", ReqData, Context}
            end;
        _ -> {true, ReqData, Context}
    end.


%% utilities

even(N) when is_integer(N) ->
    N rem 2 =:= 0.

is_bson_object(Value) when is_tuple(Value) ->
    even(tuple_size(Value));
is_bson_object(_) ->
    false.

mongo_to_mochijson2(Document) ->
    Fun = fun(Label, Value, Acc) ->
		  %io:format("mongo_to_mochijson2: Label = ~s, Value = ~s~n", [Label, Value]),
		  Val = case is_bson_object(Value) of
			    true ->
				mongo_to_mochijson2(Value);
			    false ->
				Value
			end,
		  [{Label, Val} | Acc]
	  end,
    List = bson:doc_foldr(Fun, [], Document),
    {struct, List}.

