require_relative "lib/reactive_resource/version"

Gem::Specification.new do |spec|
  spec.name = "reactive_resource"
  spec.version = ReactiveResource::VERSION
  spec.authors = ["Standard Procedure"]
  spec.email = ["rahoulb@standardprocedure.app"]
  spec.homepage = "https://theartandscienceofruby.com"
  spec.summary =
    "ReactiveResource - use Hotwire to make fully reactive components"
  spec.description =
    "ReactiveResource - use Hotwire to make fully reactive components"
  spec.license = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://theartandscienceofruby.com"
  spec.metadata["changelog_uri"] = "https://theartandscienceofruby.com"

  spec.files =
    Dir.chdir(File.expand_path(__dir__)) do
      Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
    end
  spec.test_files = Dir.chdir(File.expand_path(__dir__)) { Dir["spec/**/*"] }

  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "view_component"
  spec.add_dependency "redis"
end
