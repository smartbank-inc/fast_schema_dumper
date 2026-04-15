## [Unreleased]

## [0.5.2] - 2026-04-15

- Fix generated column dump order to match ActiveRecord::SchemaDumper. [#32](https://github.com/smartbank-inc/fast_schema_dumper/pull/32)
- Fix generated column expression dump to align with Rails output. [#33](https://github.com/smartbank-inc/fast_schema_dumper/pull/33)
- Use include-based assertions in schema dumper tests. [#31](https://github.com/smartbank-inc/fast_schema_dumper/pull/31)

## [0.5.1] - 2026-04-13

- Add unit tests for pure private methods in `FastSchemaDumper::SchemaDumper`. [#27](https://github.com/smartbank-inc/fast_schema_dumper/pull/27)
- Trim unnecessary files from gem package. [#28](https://github.com/smartbank-inc/fast_schema_dumper/pull/28)
- Add MySQL integration tests for schema dump verification. [#29](https://github.com/smartbank-inc/fast_schema_dumper/pull/29)

## [0.5.0] - 2026-04-09

- Handle generated columns in fast dumper. [#23](https://github.com/smartbank-inc/fast_schema_dumper/pull/23)
- Add frozen string literal pragmas and update README. [#25](https://github.com/smartbank-inc/fast_schema_dumper/pull/25)
- Add RubyGems version badge to README. [#17](https://github.com/smartbank-inc/fast_schema_dumper/pull/17)

## [0.4.3] - 2026-03-11

- Introduce StandardRB for code linting. [#9](https://github.com/smartbank-inc/fast_schema_dumper/pull/9)
- Test setup. [#10](https://github.com/smartbank-inc/fast_schema_dumper/pull/10)
- Add `.github/dependabot.yml`. [#12](https://github.com/smartbank-inc/fast_schema_dumper/pull/12)

## [0.4.0] - 2025-11-06

## [0.3.0] - 2025-10-31

- Support handling of CHECK constraints. [#1](https://github.com/smartbank-inc/fast_schema_dumper/pull/1)
- Always dump `orig.txt` and `fast.txt` in verify mode.

## [0.2.0] - 2025-10-03

## [0.1.0] - 2025-07-10

- Initial release
