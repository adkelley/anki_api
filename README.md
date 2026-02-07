# anki_api

Gleam bindings for the Anki-Connect API

```sh
gleam add anki_api@0.1.0
```

```gleam
import anki_api as anki

pub fn main() -> Nil {
  assert anki.open_anki() == Ok(Nil)

  let result =
    anki.default()
    |> anki.send_request()

  case result {
    Ok(Version(version)) -> {
      assert version == 6
    }
    Ok(_) -> panic as "Unexpected Anki response"
    Error(_) -> panic as "Failed to fetch Anki version"
  }
}

```

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
