%% FFI helpers for Anki.
-module(anki_ffi).
-export([os_cmd/1]).

os_cmd(Command) when is_binary(Command) ->
  os_cmd(unicode:characters_to_list(Command));

os_cmd(Command) when is_bitstring(Command) ->
  os_cmd(unicode:characters_to_list(Command));

os_cmd(Command) when is_list(Command) ->
try
  list_to_binary(os:cmd(Command))
catch
  _:_ -> <<>>
end.
