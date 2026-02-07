import anki_api.{Version} as anki
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn open_anki_test() {
  assert anki.open_anki() == Ok(Nil)
}

pub fn anki_version_test() {
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
