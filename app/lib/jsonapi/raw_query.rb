# frozen_string_literal: true

require "uri"

module Jsonapi
  # 쿼리 문자열을 디코딩하고 파라미터 형태 충돌을 판정한다.
  #
  # `filter[a]=1&filter[a][gt]=2`처럼 같은 이름이 스칼라와 컨테이너 양쪽으로 오면
  # Rack이 조용히 한쪽을 버린다. 그것을 형태 충돌로 잡아 400으로 만드는 것이
  # `ShapeTree`의 일이다.
  class RawQuery
    ERROR_CODE_BY_FAMILY = {
      "filter" => "INVALID_FILTER",
      "sort" => "INVALID_SORT",
      "include" => "INVALID_INCLUDE",
      "page" => "INVALID_PAGE"
    }.freeze
    PARAMETER = /\A([^\[\]]+)((?:\[[^\[\]]*\])*)\z/
    SEGMENT = /\[([^\[\]]*)\]/

    class ShapeTree
      class Node
        attr_accessor :terminal, :container_kind
        attr_reader :children

        def initialize
          @terminal = false
          @container_kind = nil
          @children = {}
        end
      end
      private_constant :Node

      def initialize
        @root = Node.new
      end

      def conflict?(segments)
        node = @root
        segments.each do |segment|
          return true if node.terminal

          kind = container_kind(segment)
          return true if node.container_kind && node.container_kind != kind

          node = node.children[segment]
          return false unless node
        end

        !node.container_kind.nil?
      end

      def add(segments)
        node = @root
        segments.each do |segment|
          node.container_kind ||= container_kind(segment)
          node = node.children[segment] ||= Node.new
        end
        node.terminal = true
      end

      private

      def container_kind(segment)
        segment.empty? ? :array : :hash
      end
    end
    private_constant :ShapeTree

    class << self
      def decode(query_string)
        return [] if query_string.empty?

        pairs = URI.decode_www_form(query_string, Encoding::UTF_8)
        raise ArgumentError unless pairs.flatten.all?(&:valid_encoding?)

        pairs
      end

      def shape_conflict(pairs)
        sanitize_shape_conflicts(pairs).first
      end

      def sanitize_shape_conflicts(pairs)
        conflict = nil
        shape_trees = {}
        sanitized_pairs = pairs.reject do |parameter, _|
          segments = parameter_segments(parameter)
          next false unless segments

          family = segments.first
          shape_tree = shape_trees[family] ||= ShapeTree.new
          if shape_tree.conflict?(segments.drop(1))
            conflict ||= [ ERROR_CODE_BY_FAMILY.fetch(family, "INVALID_QUERY_PARAMETER"), parameter ]
            next true
          end

          shape_tree.add(segments.drop(1))
          false
        end

        [ conflict, sanitized_pairs ]
      end

      private

      def parameter_segments(parameter)
        match = PARAMETER.match(parameter)
        return unless match

        [ match[1], *match[2].scan(SEGMENT).flatten ]
      end
    end
  end
end
