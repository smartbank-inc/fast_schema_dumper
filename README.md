# fast_schema_dumper

A super fast alternative to ActiveRecord::SchemaDumper. Currently only MySQL is supported.

## Usage

### Ridgepole integration

Requiring `fast_schema_dumper/ridgepole` will overwrite `Ridgepole::Dumper.dump`, which will force Ridgepole to use fast_schema_dumper.

```
RUBYOPT='-rridgepole -rfast_schema_dumper' ridgepole ... --apply
```

#### Environment variables for Ridgepole

The Ridgepole integration is configurable via envionment variables.

- `FAST_SCHEMA_DUMPER_MODE`:
  - `disabled`: Use the original ActiveRecord dumper
  - `verify`: Run both dumpers and verify output matches (useful for testing)
  - Any other value or unset: Use FastSchemaDumper (default)
- `FAST_SCHEMA_DUMPER_SUPPRESS_MESSAGE=1`: Suppress the warning message when FastSchemaDumper is enabled

I recommend using only fast_schema_dumper in local development environments, and configuring `FAST_SCHEMA_DUMPER_MODE=verify` in CI setups.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add fast_schema_dumper
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install fast_schema_dumper
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/fast_schema_dumper.

## Releasing

Kick the GitHub Actions workflow.
