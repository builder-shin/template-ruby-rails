# frozen_string_literal: true

require "rails_helper"
require "ripper"

RSpec.describe "SimpleCov configuration" do
  let(:rails_helper_source) { Rails.root.join("spec/rails_helper.rb").read }

  def call_declarations(source, method_name)
    syntax_tree = Ripper.sexp(source)
    raise SyntaxError, "Invalid Ruby source" unless syntax_tree

    lines = source.lines
    start_blocks = syntax_tree[1].select { |statement| simplecov_start_block?(statement) }
    return [] unless start_blocks.one?

    start_block = start_blocks.first
    start_token = direct_call_token(start_block[1])
    return [] unless lines.fetch(start_token[2].first - 1).strip == 'SimpleCov.start "rails" do'

    direct_block_statements(start_block).filter_map do |statement|
      method_token = direct_call_token(statement)
      lines.fetch(method_token[2].first - 1).strip if method_token&.first == :@ident && method_token[1] == method_name
    end
  end

  def direct_call_token(node)
    case node&.first
    when :command, :fcall, :vcall
      node[1]
    when :call, :command_call
      node[3]
    when :method_add_arg, :method_add_block
      direct_call_token(node[1])
    end
  end

  def direct_call_receiver(node)
    case node&.first
    when :call, :command_call
      node[1]
    when :method_add_arg, :method_add_block
      direct_call_receiver(node[1])
    end
  end

  def simplecov_start_block?(node)
    return false unless node&.first == :method_add_block

    method_token = direct_call_token(node[1])
    receiver = direct_call_receiver(node[1])
    method_token&.first == :@ident && method_token[1] == "start" &&
      receiver&.first == :var_ref && receiver.dig(1, 0) == :@const && receiver.dig(1, 1) == "SimpleCov"
  end

  def direct_block_statements(start_block)
    block = start_block[2]
    body = block[2]
    return [] unless block.first == :do_block && body&.first == :bodystmt

    body[1] || []
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
      SimpleCov.start "rails" do
        # minimum_coverage ENV.fetch("COVERAGE_MINIMUM", "80").to_f
        minimum_coverage ENV.fetch("COVERAGE_MINIMUM", "81").to_f
        minimum_coverage ENV.fetch("COVERAGE_MINIMUM", "80").to_f
        # track_files "app/**/*.rb"
        track_files "lib/**/*.rb"
        track_files "app/**/*.rb"
      end
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
      SimpleCov.start "rails" do
        add_filter("tmp/")
        add_filter %r{/generated/}
        add_filter do |source_file|
          source_file.filename.include?("ignored")
        end
        SimpleCov.add_filter("receiver/")
      end
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

  it "excludes declarations inside unreachable branches and method definitions" do
    source = <<~RUBY
      SimpleCov.start "rails" do
        if false
          minimum_coverage ENV.fetch("COVERAGE_MINIMUM", "80").to_f
          add_filter "app/channels/application_cable/"
        end

        def deferred_coverage
          track_files "app/**/*.rb"
          add_filter "app/helpers/application_helper.rb"
        end
      end
    RUBY

    expect(call_declarations(source, "minimum_coverage")).to be_empty
    expect(call_declarations(source, "track_files")).to be_empty
    expect(call_declarations(source, "add_filter")).to be_empty
  end

  it "rejects duplicate rails profile blocks" do
    source = <<~RUBY
      SimpleCov.start "rails" do
      end

      SimpleCov.start "rails" do
        track_files "app/**/*.rb"
      end
    RUBY

    expect(call_declarations(source, "track_files")).to be_empty
  end
end
