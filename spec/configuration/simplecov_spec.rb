# frozen_string_literal: true

require "rails_helper"
require "ripper"

RSpec.describe "SimpleCov configuration" do
  let(:rails_helper_source) { Rails.root.join("spec/rails_helper.rb").read }

  def call_declarations(source, method_name)
    syntax_tree = Ripper.sexp(source)
    raise SyntaxError, "Invalid Ruby source" unless syntax_tree

    lines = source.lines
    call_line_numbers(syntax_tree, method_name).map { |line_number| lines.fetch(line_number - 1).strip }
  end

  def call_line_numbers(node, method_name)
    return [] unless node.is_a?(Array)

    method_token = case node.first
    when :command, :fcall, :vcall
      node[1]
    when :call, :command_call
      node[3]
    end

    line_numbers = []
    if method_token&.first == :@ident && method_token[1] == method_name
      line_numbers << method_token[2].first
    end

    node.each do |child|
      line_numbers.concat(call_line_numbers(child, method_name)) if child.is_a?(Array)
    end
    line_numbers
  end

  it "uses the environment minimum with an 80 percent default" do
    expect(call_declarations(rails_helper_source, "minimum_coverage")).to eq(
      [ 'minimum_coverage ENV.fetch("COVERAGE_MINIMUM", "80").to_f' ]
    )
    expect(SimpleCov.minimum_coverage.fetch(:line)).to eq(ENV.fetch("COVERAGE_MINIMUM", "80").to_f)
  end

  it "tracks exactly the application Ruby files" do
    expect(call_declarations(rails_helper_source, "track_files")).to eq([ 'track_files "app/**/*.rb"' ])
  end

  it "filters exactly the approved generated base files" do
    expect(call_declarations(rails_helper_source, "add_filter")).to eq(
      [
        'add_filter "app/channels/application_cable/"',
        'add_filter "app/helpers/application_helper.rb"',
        'add_filter "app/mailers/application_mailer.rb"'
      ]
    )
  end

  it "ignores matching comments and preserves actual duplicate declarations" do
    source = <<~RUBY
      # minimum_coverage ENV.fetch("COVERAGE_MINIMUM", "80").to_f
      minimum_coverage ENV.fetch("COVERAGE_MINIMUM", "81").to_f
      minimum_coverage ENV.fetch("COVERAGE_MINIMUM", "80").to_f
      # track_files "app/**/*.rb"
      track_files "lib/**/*.rb"
      track_files "app/**/*.rb"
    RUBY

    expect(call_declarations(source, "minimum_coverage")).to eq(
      [
        'minimum_coverage ENV.fetch("COVERAGE_MINIMUM", "81").to_f',
        'minimum_coverage ENV.fetch("COVERAGE_MINIMUM", "80").to_f'
      ]
    )
    expect(call_declarations(source, "track_files")).to eq(
      [ 'track_files "lib/**/*.rb"', 'track_files "app/**/*.rb"' ]
    )
  end

  it "collects parenthesized, regexp, block, and receiver filter calls" do
    source = <<~RUBY
      add_filter("tmp/")
      add_filter %r{/generated/}
      add_filter do |source_file|
        source_file.filename.include?("ignored")
      end
      SimpleCov.add_filter("receiver/")
    RUBY

    expect(call_declarations(source, "add_filter")).to eq(
      [
        'add_filter("tmp/")',
        'add_filter %r{/generated/}',
        'add_filter do |source_file|',
        'SimpleCov.add_filter("receiver/")'
      ]
    )
  end
end
