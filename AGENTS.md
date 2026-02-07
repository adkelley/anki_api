# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Project Overview

`anki_api` is an SDK for the [Anki Connect API](https://git.sr.ht/~foosoft/anki-connect) written in Gleam. Ultimately it will wrap this HTTP API with
typed request/response Gleam structures, mapping the supported actions without hand-writing JSON plumbing.

## Best Coding Practices
### Documentation
- Documentation lines for public functions and public types are prefixed with '/// '
- Documentation lines for private functions and types are prefixed witn '//'
- Todos are prefixed witn '// TODO '
- If you reference a function in your documentation, use Gleam syntax, only
### Functions
- If a utility function is called by one function only, then embed the utility function inside the calling function by using a `let` statement.


## Essential Commands

### Development
- `gleam deps download` - Install dependencies
- `gleam format` - Format the code
- `gleam test` - Run all tests
