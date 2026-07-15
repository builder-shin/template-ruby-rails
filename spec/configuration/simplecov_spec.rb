# frozen_string_literal: true

require "rails_helper"
require "ripper"

RSpec.describe "SimpleCov configuration" do
  let(:rails_helper_source) { Rails.root.join("spec/rails_helper.rb").read }

  def call_declarations(source, method_name)
    syntax_tree = Ripper.sexp(source)
    raise SyntaxError, "Invalid Ruby source" unless syntax_tree

    lines = source.lines
    start_blocks = syntax_tree[1].select { |statement| approved_start_block?(statement, lines) }
    return [] unless start_blocks.one?

    start_block = start_blocks.first
    direct_calls = direct_block_statements(start_block).filter_map { |statement| base_call(statement) }
    allowed_calls = [ base_call(start_block), *direct_calls.select { |call| direct_mutator?(call) } ]
    return [] unless mutation_calls(syntax_tree, start_block:).all? do |mutation|
      allowed_calls.any? { |allowed| allowed.equal?(mutation) }
    end

    direct_calls.filter_map do |call|
      lines.fetch(call_token(call)[2].first - 1).strip if call_name(call) == method_name
    end
  end

  def base_call(node)
    case node&.first
    when :command, :fcall, :vcall, :call, :command_call
      node
    when :method_add_arg, :method_add_block
      base_call(node[1])
    end
  end

  def call_token(call)
    %i[ command fcall vcall ].include?(call.first) ? call[1] : call[3]
  end

  def call_name(call)
    call_token(call)[1]
  end

  def approved_start_block?(node, lines)
    return false unless node&.first == :method_add_block

    call = base_call(node)
    simplecov_call?(call, "start") &&
      lines.fetch(call_token(call)[2].first - 1).strip == 'SimpleCov.start "rails" do'
  end

  def simplecov_call?(call, method_name)
    receiver = call[1] if %i[ call command_call ].include?(call&.first)
    call && call_name(call) == method_name && simplecov_receiver?(receiver)
  end

  def simplecov_receiver?(receiver)
    case receiver&.first
    when :var_ref, :top_const_ref
      receiver.dig(1, 0) == :@const && receiver.dig(1, 1) == "SimpleCov"
    when :const_path_ref
      namespace, name = receiver[1], receiver[2]
      %i[ var_ref top_const_ref ].include?(namespace&.first) &&
        namespace.dig(1, 0) == :@const && namespace.dig(1, 1) == "Object" &&
        name&.first == :@const && name[1] == "SimpleCov"
    when :paren
      expressions = receiver[1]
      expressions.one? && simplecov_receiver?(expressions.first)
    else
      false
    end
  end

  def direct_mutator?(call)
    %w[ track_files minimum_coverage add_filter ].include?(call_name(call))
  end

  def mutation_calls(node, start_block:, inside_start_block: false)
    return [] unless node.is_a?(Array)

    inside_start_block ||= node.equal?(start_block)
    children = node.filter { |child| child.is_a?(Array) }.flat_map do |child|
      mutation_calls(child, start_block:, inside_start_block:)
    end
    call = base_call(node)
    dsl_filters = inside_start_block && call&.first == :vcall && call_name(call) == "filters"
    is_mutation = call.equal?(node) &&
      (direct_mutator?(call) || dsl_filters ||
       %w[ start configure filters ].any? { |name| simplecov_call?(call, name) })
    is_mutation ? [ call, *children ] : children
  end

  def direct_block_statements(start_block)
    block = start_block[2]
    body = block[2]
    return [] unless block.first == :do_block && body&.first == :bodystmt

    body[1] || []
  end

  def valid_source(inside: [], after: [])
    lines = [
      'SimpleCov.start "rails" do',
      '  track_files "app/**/*.rb"',
      '  minimum_coverage ENV.fetch("COVERAGE_MINIMUM", "80").to_f',
      '  add_filter "app/channels/application_cable/"',
      '  add_filter "app/helpers/application_helper.rb"',
      '  add_filter "app/mailers/application_mailer.rb"',
      *inside.map { |line| "  #{line}" },
      "end",
      *after
    ]
    "#{lines.join("\n")}\n"
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

  it "ignores receiverless filters access outside the approved start block" do
    source = valid_source(after: [ "filters.clear", 'filters << "app/generated/"' ])

    expect(call_declarations(source, "track_files")).to eq([ 'track_files "app/**/*.rb"' ])
  end

  it "rejects every mutation outside the approved direct nodes" do
    sources = {
      "configure block" => valid_source(after: [ 'SimpleCov.configure { add_filter "configured/" }' ]),
      "module filter" => valid_source(after: [ 'SimpleCov.add_filter "module/"' ]),
      "conditional filter" => valid_source(inside: [ "if false", '  add_filter "conditional/"', "end" ]),
      "conditional minimum" => valid_source(
        inside: [ "if false", '  minimum_coverage ENV.fetch("COVERAGE_MINIMUM", "80").to_f', "end" ]
      ),
      "deferred track" => valid_source(inside: [ "def deferred", '  track_files "app/**/*.rb"', "end" ]),
      "nested start" => valid_source(
        inside: [ 'SimpleCov.start "rails" do', "end" ]
      ),
      "duplicate start" => valid_source(after: [ 'SimpleCov.start "rails" do', "end" ]),
      "blockless start" => valid_source(after: [ 'SimpleCov.start "rails"' ]),
      "top-level constant blockless start" => valid_source(after: [ '::SimpleCov.start "rails"' ]),
      "Object path blockless start" => valid_source(after: [ 'Object::SimpleCov.start "rails"' ]),
      "top-level Object path blockless start" => valid_source(after: [ '::Object::SimpleCov.start "rails"' ]),
      "cleared filter collection" => valid_source(after: [ "SimpleCov.filters.clear" ]),
      "appended filter collection" => valid_source(after: [ 'SimpleCov.filters << "app/generated/"' ]),
      "cleared DSL filter collection" => valid_source(inside: [ "filters.clear" ]),
      "appended DSL filter collection" => valid_source(inside: [ 'filters << "app/generated/"' ]),
      "parenthesized nested start" => valid_source(inside: [ '(SimpleCov).start "rails" do', "end" ])
    }

    aggregate_failures do
      sources.each do |label, source|
        expect(call_declarations(source, "add_filter")).to be_empty, label
      end
    end
  end
end
