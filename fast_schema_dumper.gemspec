require_relative "lib/fast_schema_dumper/version"

Gem::Specification.new do |spec|
  spec.name = "fast_schema_dumper"
  spec.version = FastSchemaDumper::VERSION
  spec.authors = ["Daisuke Aritomo"]
  spec.email = ["osyoyu@osyoyu.com"]

  spec.summary = "A fast alternative to ActiveRecord::SchemaDumper"
  spec.homepage = "https://github.com/osyoyu/fast_schema_dumper"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/osyoyu/fast_schema_dumper"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .github])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord"
end
