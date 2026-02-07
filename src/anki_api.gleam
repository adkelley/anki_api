import gleam/dynamic/decode
import gleam/http
import gleam/http/request as http_request

import gleam/httpc
import gleam/json.{type Json}
import gleam/option
import gleam/result
import gleam/string

const anki_url: String = "http://127.0.0.1:8765"

pub opaque type Request {
  Request(action: String, version: Int, params: Json)
}

pub type AnkiError {
  HttpError
  JsonParseError
  OpenAnkiError
}

pub type Anki {
  Version(Int)
  DeckNames(List(String))
  FindCards(List(Int))
  FindNotes(List(Int))
  GetNotesTags(List(String))
  UpdateNoteFields(String)
  ActionError(String)
}

@external(erlang, "anki_ffi", "os_cmd")
fn os_cmd(command: String) -> String

pub fn open_anki() -> Result(Nil, AnkiError) {
  let is_anki_running = fn() -> Bool {
    os_cmd("osascript -e 'application \"Anki\" is running'")
    |> string.contains("true")
  }

  case is_anki_running() {
    True -> Ok(Nil)
    False -> {
      let _ =
        os_cmd(
          "osascript "
          <> "-e 'tell application \"Anki\" to activate' "
          <> "-e 'delay 1'",
        )

      case is_anki_running() {
        True -> Ok(Nil)
        False -> Error(OpenAnkiError)
      }
    }
  }
}

pub fn default() -> Request {
  Request(action: "version", version: 6, params: json.null())
}

pub fn deck_names(config: Request) -> Request {
  Request(..config, action: "deckNames")
}

pub fn find_cards(config: Request, query: String) -> Request {
  let params = json.object([#("query", json.string(query))])
  Request(..config, action: "findCards", params:)
}

pub fn find_notes(config: Request, query: String) -> Request {
  let params = json.object([#("query", json.string(query))])
  Request(..config, action: "findNotes", params:)
}

pub fn get_note_tags(config: Request, id: Int) -> Request {
  let params = json.object([#("note", json.int(id))])
  Request(..config, action: "getNoteTags", params:)
}

pub fn field_to_json(name: String, value: String) -> Json {
  json.object([#(name, json.string(value))])
}

pub fn update_note_fields(config: Request, id: Int, fields: Json) -> Request {
  let params =
    json.object([
      #(
        "note",
        json.object([
          #("id", json.int(id)),
          #("fields", fields),
        ]),
      ),
    ])
  Request(..config, action: "updateNoteFields", params:)
}

pub fn send_request(request: Request) -> Result(Anki, AnkiError) {
  let assert Ok(base_req) = http_request.to(anki_url)

  let request_encoder = fn() -> Json {
    json.object(case request.params != json.null() {
      True -> [
        #("params", request.params),
        #("action", json.string(request.action)),
        #("version", json.int(request.version)),
      ]
      False -> [
        #("action", json.string(request.action)),
        #("version", json.int(request.version)),
      ]
    })
  }

  let body =
    request_encoder()
    |> json.to_string
    |> echo

  let req =
    base_req
    |> http_request.prepend_header("Content-Type", "application/json")
    |> http_request.set_body(body)
    |> http_request.set_method(http.Post)

  use resp <- result.try(
    httpc.configure()
    |> httpc.dispatch(req)
    |> result.replace_error(HttpError),
  )

  use result <- result.try(
    json.parse(resp.body, response_decoder(request.action))
    |> result.replace_error(JsonParseError),
  )

  Ok(result)
}

fn version_decoder() -> decode.Decoder(Anki) {
  use version <- decode.field("result", decode.optional(decode.int))
  use error <- decode.field("error", decode.optional(decode.string))
  case option.is_some(version) {
    True -> decode.success(Version(option.unwrap(version, 0)))

    False -> decode.success(ActionError(option.unwrap(error, "")))
  }
}

fn deck_names_decoder() -> decode.Decoder(Anki) {
  use deck_names <- decode.field(
    "result",
    decode.optional(decode.list(decode.string)),
  )
  use error <- decode.field("error", decode.optional(decode.string))
  case option.is_some(deck_names) {
    True -> decode.success(DeckNames(option.unwrap(deck_names, [])))

    False -> decode.success(ActionError(option.unwrap(error, "")))
  }
}

fn find_cards_decoder() -> decode.Decoder(Anki) {
  use card_ids <- decode.field(
    "result",
    decode.optional(decode.list(decode.int)),
  )
  use error <- decode.field("error", decode.optional(decode.string))
  case option.is_some(card_ids) {
    True -> decode.success(FindCards(option.unwrap(card_ids, [])))

    False -> decode.success(ActionError(option.unwrap(error, "")))
  }
}

fn find_notes_decoder() -> decode.Decoder(Anki) {
  use note_ids <- decode.field(
    "result",
    decode.optional(decode.list(decode.int)),
  )
  use error <- decode.field("error", decode.optional(decode.string))
  case option.is_some(note_ids) {
    True -> decode.success(FindNotes(option.unwrap(note_ids, [])))

    False -> decode.success(ActionError(option.unwrap(error, "")))
  }
}

fn get_note_tags_decoder() -> decode.Decoder(Anki) {
  use note_tags <- decode.field(
    "result",
    decode.optional(decode.list(decode.string)),
  )
  use error <- decode.field("error", decode.optional(decode.string))
  case option.is_some(note_tags) {
    True -> decode.success(GetNotesTags(option.unwrap(note_tags, [])))

    False -> decode.success(ActionError(option.unwrap(error, "")))
  }
}

// Modify the fields of an existing note. You can also include audio, video, 
// or picture files which will be added to the note with an optional audio,
// video, or picture property. Please see the documentation for addNote for an
// explanation of objects in the audio, video, or picture array.
//
// Warning: You must not be viewing the note that you are updating on your
// Anki browser, otherwise the fields will not update. See this issue for 
// further details.
// 
// https://git.sr.ht/~foosoft/anki-connect#codeupdatenotefieldscode
// 
fn update_note_fields_decoder() -> decode.Decoder(Anki) {
  use result <- decode.field("result", decode.optional(decode.string))
  use error <- decode.field("error", decode.optional(decode.string))
  case option.is_none(result) && option.is_none(error) {
    True ->
      decode.success(
        UpdateNoteFields(option.unwrap(result, "UpdateNoteFields succeeded")),
      )

    False ->
      decode.success(
        ActionError(option.unwrap(error, "UpdateNoteFields failed")),
      )
  }
}

fn response_decoder(action: String) -> decode.Decoder(Anki) {
  case action {
    "version" -> version_decoder()
    "deckNames" -> deck_names_decoder()
    "findCards" -> find_cards_decoder()
    "findNotes" -> find_notes_decoder()
    "getNoteTags" -> get_note_tags_decoder()
    "updateNoteFields" -> update_note_fields_decoder()
    _ -> panic as "No decoder defined for action"
  }
}
