require 'asciidoctor'
require 'erb'

options = {:mkdirs => true, :safe => :unsafe, :attributes => 'linkcss'}

guard 'shell' do
  watch(/^[A-Za-z].*\.adoc$/) {|m|
    Asciidoctor.load_file('src/main/asciidoc/README.adoc', :to_file => './README.adoc', safe: :safe, parse: false)
    Asciidoctor.render_file('src/main/asciidoc/spring-cloud-build.adoc', options.merge(:to_dir => 'target/generated-docs'))
    Asciidoctor.render_file('src/main/asciidoc/building.adoc', options.merge(:to_dir => 'target/generated-docs'))
  }
end
