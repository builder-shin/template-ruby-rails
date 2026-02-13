# frozen_string_literal: true

namespace :data do
  desc "Migrate data from original Railway DB (camelCase) to Rails DB (snake_case)"
  task migrate: :environment do
    require 'pg'

    SOURCE_DB = {
      host: 'switchback.proxy.rlwy.net',
      port: 46113,
      dbname: 'railway',
      user: 'postgres',
      password: 'JbkuMuXarMzVeIBKFghwecutvIwKqQIQ'
    }.freeze

    # 테이블 마이그레이션 순서 (FK 의존성 고려)
    TABLES = %w[
      countries
      job_categories
      jobs
      highlight_references
      practical_strength_references
      application_context_references
      email_templates
      profiles
      profile_attachments
      profile_educations
      profile_experiences
      profile_freelance_experiences
      profile_highlights
      profile_jobs
      profile_languages
      profile_links
      profile_projects
      featured_profiles
      job_posts
      job_post_categories
      job_post_jobs
      job_post_languages
      job_post_status_logs
      job_applications
      career_hub_categories
      career_hub_community_leaders
      career_hub_communities
      career_hub_community_members
      career_hub_community_events
      career_hub_community_event_participants
      career_hub_community_feeds
      career_hub_community_feed_likes
      career_hub_event_reviews
      event_notification_schedules
      recommendation_notification_history
    ].freeze

    # 특수 컬럼 매핑 (Rails 컨벤션으로 변경된 컬럼)
    SPECIAL_MAPPINGS = {
      'isEmailPublic' => 'email_public',
      'isPriority' => 'priority'
    }.freeze

    def camel_to_snake(str)
      return SPECIAL_MAPPINGS[str] if SPECIAL_MAPPINGS.key?(str)
      str.gsub(/([A-Z])/) { "_#{$1.downcase}" }.sub(/^_/, '')
    end

    conn = PG.connect(SOURCE_DB)

    TABLES.each do |table|
      puts "\n=== Migrating #{table} ==="

      # 원본 테이블 컬럼 조회
      columns_result = conn.exec(<<~SQL)
        SELECT column_name FROM information_schema.columns
        WHERE table_name = '#{table}' AND table_schema = 'public'
        ORDER BY ordinal_position
      SQL

      source_columns = columns_result.map { |r| r['column_name'] }

      # 데이터 조회
      data = conn.exec("SELECT * FROM #{table}")

      if data.ntuples == 0
        puts "  No data to migrate"
        next
      end

      # 대상 모델 찾기
      model_name = table.singularize.camelize
      model_name = 'RecommendationNotificationHistory' if table == 'recommendation_notification_history'

      begin
        model = model_name.constantize
      rescue NameError
        puts "  Model #{model_name} not found, skipping"
        next
      end

      # Rails 테이블의 컬럼 목록
      target_columns = model.column_names

      # 컬럼 매핑 (camelCase -> snake_case)
      column_mapping = {}
      source_columns.each do |src_col|
        snake_col = camel_to_snake(src_col)
        column_mapping[src_col] = snake_col if target_columns.include?(snake_col)
      end

      puts "  Found #{data.ntuples} records"
      puts "  Column mapping: #{column_mapping.keys.count} columns"

      success = 0
      errors = 0

      # 테이블별 primary key 설정
      pk_config = {
        'email_templates' => ['key'],
        'profile_jobs' => %w[profile_id job_id],
        'job_post_categories' => %w[job_post_id job_category_id],
        'job_post_jobs' => %w[job_post_id job_id]
      }
      pk_columns = pk_config[table] || ['id']
      has_id = pk_columns == ['id']

      # Enum 컬럼 목록 (소문자 변환 필요)
      enum_columns = model.defined_enums.keys

      data.each do |row|
        attrs = {}
        column_mapping.each do |src, dst|
          value = row[src]

          # JSON/Array 타입 변환
          if value.is_a?(String) && (value.start_with?('{') || value.start_with?('['))
            begin
              value = JSON.parse(value)
            rescue JSON::ParserError
              # 그대로 사용
            end
          end

          # Enum 값 소문자 변환
          if enum_columns.include?(dst) && value.is_a?(String)
            value = value.downcase
          end

          attrs[dst] = value
        end

        begin
          if has_id
            # id가 있는 테이블: upsert
            record = model.find_or_initialize_by(id: attrs['id'])
            record.assign_attributes(attrs.except('id'))
            record.id = attrs['id'] if attrs['id']
          else
            # 복합키/다른 pk 테이블: pk 기준으로 upsert
            pk_attrs = attrs.slice(*pk_columns)
            record = model.find_or_initialize_by(pk_attrs)
            record.assign_attributes(attrs.except(*pk_columns))
          end
          record.save!(validate: false)
          success += 1
        rescue => e
          errors += 1
          puts "  Error: #{e.message}" if errors <= 3
        end
      end

      puts "  Migrated: #{success}, Errors: #{errors}"
    end

    conn.close
    puts "\n=== Migration complete ==="
  end

  desc "Check column mapping between source and target"
  task check_mapping: :environment do
    require 'pg'

    SOURCE_DB = {
      host: 'switchback.proxy.rlwy.net',
      port: 46113,
      dbname: 'railway',
      user: 'postgres',
      password: 'JbkuMuXarMzVeIBKFghwecutvIwKqQIQ'
    }.freeze

    # 특수 컬럼 매핑 (Rails 컨벤션으로 변경된 컬럼)
    SPECIAL_MAPPINGS = {
      'isEmailPublic' => 'email_public',
      'isPriority' => 'priority'
    }.freeze

    def camel_to_snake(str)
      return SPECIAL_MAPPINGS[str] if SPECIAL_MAPPINGS.key?(str)
      str.gsub(/([A-Z])/) { "_#{$1.downcase}" }.sub(/^_/, '')
    end

    conn = PG.connect(SOURCE_DB)

    table = ENV['TABLE'] || 'profiles'
    puts "=== Checking #{table} ==="

    # 원본 컬럼
    columns = conn.exec(<<~SQL).map { |r| r['column_name'] }
      SELECT column_name FROM information_schema.columns
      WHERE table_name = '#{table}' AND table_schema = 'public'
      ORDER BY ordinal_position
    SQL

    # Rails 컬럼
    model_name = table.singularize.camelize
    model = model_name.constantize
    target_columns = model.column_names

    puts "\nSource -> Target mapping:"
    columns.each do |src|
      snake = camel_to_snake(src)
      status = target_columns.include?(snake) ? '✓' : '✗ MISSING'
      puts "  #{src} -> #{snake} #{status}"
    end

    missing = columns.map { |c| camel_to_snake(c) } - target_columns
    extra = target_columns - columns.map { |c| camel_to_snake(c) }

    puts "\nMissing in Rails: #{missing.join(', ')}" if missing.any?
    puts "Extra in Rails: #{extra.join(', ')}" if extra.any?

    conn.close
  end
end
