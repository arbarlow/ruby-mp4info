Gem::Specification.new do |s|
  s.name = %q{mp4info}
  s.version = "1.7.3"
 
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["arbarlow"]
  s.date = %q{2009-09-17}
  s.description = %q{Rubygem for getting and setting mp4 info}
  s.email = %q{alexbarlowis@me.com}
  s.extra_rdoc_files = [
     "README.rdoc"
  ]
  s.files = [
    "docs/license.txt",
     "lib/mp4info-windows-binmode.patch",
     "lib/mp4info.rb"
  ]
  s.homepage = %q{http://github.com/arbarlow/ruby-mp4info/}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Rubygem for getting and setting mp4 info}
  s.test_files = [
    "test/test.rb",
  ]
 
  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3
 
    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end