# Contributing

Thank you for considering a contribution.

## How to contribute

1. Open an issue first for larger changes so that the approach can be discussed.
2. Fork the repository and create a branch from `main`.
3. Develop and test the change in an S/4HANA system, then push it with abapGit.
4. Make sure `abaplint` passes (it runs automatically on every pull request).
5. Open a pull request and describe what changed and why.

## Code conventions

- Language of identifiers, comments and documentation: English. UI texts belong in message
  class ZSD_APM so that they can be translated.
- Modern ABAP: inline declarations, constructor expressions, no FORM routines, no obsolete
  statements (see `abaplint.json` for the enforced rules).
- Global classes and interfaces are documented with ABAP Doc (`"!`). Inside function group
  includes normal comments (`*` at column 1 or `"`) are used because ABAP Doc is not evaluated there.
- No generated comment blocks (SE24 `<SIGNATURE>` blocks) in the sources.
- Keep SAP GUI control handling in the function group; keep everything that can be unit tested
  (scope, reader) in global classes.
- Do not add customer tables unless the feature cannot be built without them.

## Reporting bugs

Please include the S/4HANA release, the transaction, the document category and, if possible, a
short dump or the exact message text.
