# frozen_string_literal: true

namespace :fdw do
  desc "Setup FDW connection to Auth DB"
  task setup: :environment do
    puts "Setting up FDW connection to Auth DB..."

    connection = ActiveRecord::Base.connection

    begin
      # Read credentials from environment
      auth_host = ENV.fetch("AUTH_DB_HOST")
      auth_port = ENV.fetch("AUTH_DB_PORT")
      auth_name = ENV.fetch("AUTH_DB_NAME")
      auth_user = ENV.fetch("AUTH_DB_USER")
      auth_pass = ENV.fetch("AUTH_DB_PASSWORD")
      local_user = ENV.fetch("DEV_DATABASE_USERNAME", "postgres")

      # 1. Enable postgres_fdw extension
      connection.execute("CREATE EXTENSION IF NOT EXISTS postgres_fdw")
      puts "  ✓ postgres_fdw extension enabled"

      # 2. Create auth schema
      connection.execute("CREATE SCHEMA IF NOT EXISTS auth")
      puts "  ✓ auth schema created"

      # 3. Drop existing server if exists (for idempotency)
      connection.execute("DROP SERVER IF EXISTS auth_db_server CASCADE")

      # 4. Create foreign server with properly quoted values
      connection.execute(<<~SQL)
        CREATE SERVER auth_db_server
          FOREIGN DATA WRAPPER postgres_fdw
          OPTIONS (host #{connection.quote(auth_host)}, port #{connection.quote(auth_port)}, dbname #{connection.quote(auth_name)})
      SQL
      puts "  ✓ Foreign server auth_db_server created"

      # 5. Create user mapping with properly quoted values
      connection.execute(<<~SQL)
        CREATE USER MAPPING FOR #{connection.quote_column_name(local_user)}
          SERVER auth_db_server
          OPTIONS (user #{connection.quote(auth_user)}, password #{connection.quote(auth_pass)})
      SQL
      puts "  ✓ User mapping created for #{local_user}"

      # 6. Create foreign table: auth.users (EXCLUDING password_hash)
      connection.execute(<<~SQL)
        CREATE FOREIGN TABLE IF NOT EXISTS auth.users (
          id UUID NOT NULL,
          email VARCHAR(255) NOT NULL,
          name VARCHAR(255),
          workspace_id UUID,
          auth_method VARCHAR(50),
          verified_at TIMESTAMPTZ,
          created_at TIMESTAMPTZ,
          updated_at TIMESTAMPTZ,
          mobile VARCHAR(20),
          job_id UUID
        )
          SERVER auth_db_server
          OPTIONS (schema_name 'public', table_name 'users')
      SQL
      puts "  ✓ Foreign table auth.users created"

      # 7. Create foreign table: auth.user_consents (EXCLUDING ip_address, user_agent)
      connection.execute(<<~SQL)
        CREATE FOREIGN TABLE IF NOT EXISTS auth.user_consents (
          id UUID NOT NULL,
          user_id UUID NOT NULL,
          consent_type VARCHAR(50),
          is_agreed BOOLEAN,
          consent_version VARCHAR(20),
          agreed_at TIMESTAMPTZ,
          withdrawn_at TIMESTAMPTZ,
          created_at TIMESTAMPTZ,
          updated_at TIMESTAMPTZ
        )
          SERVER auth_db_server
          OPTIONS (schema_name 'public', table_name 'user_consents')
      SQL
      puts "  ✓ Foreign table auth.user_consents created"

      # 8. Create foreign table: auth.workspaces
      connection.execute(<<~SQL)
        CREATE FOREIGN TABLE IF NOT EXISTS auth.workspaces (
          id UUID NOT NULL,
          kind VARCHAR(50),
          name VARCHAR(255),
          domain VARCHAR(255),
          status VARCHAR(20),
          invite_code VARCHAR(32),
          created_at TIMESTAMPTZ,
          updated_at TIMESTAMPTZ
        )
          SERVER auth_db_server
          OPTIONS (schema_name 'public', table_name 'workspaces')
      SQL
      puts "  ✓ Foreign table auth.workspaces created"

      # 9. Create foreign table: auth.workspace_members
      connection.execute(<<~SQL)
        CREATE FOREIGN TABLE IF NOT EXISTS auth.workspace_members (
          workspace_id UUID NOT NULL,
          user_id UUID NOT NULL,
          role VARCHAR(20),
          member_status VARCHAR(20),
          invited_at TIMESTAMPTZ,
          joined_at TIMESTAMPTZ,
          invited_by UUID,
          status_changed_at TIMESTAMPTZ,
          created_at TIMESTAMPTZ,
          updated_at TIMESTAMPTZ
        )
          SERVER auth_db_server
          OPTIONS (schema_name 'public', table_name 'workspace_members')
      SQL
      puts "  ✓ Foreign table auth.workspace_members created"

      puts "\n✅ FDW setup complete!"
    rescue KeyError => e
      puts "\n❌ Missing required environment variable: #{e.message}"
      puts "   Required: AUTH_DB_HOST, AUTH_DB_PORT, AUTH_DB_NAME, AUTH_DB_USER, AUTH_DB_PASSWORD"

      # Cleanup on failure
      begin
        connection.execute("DROP SCHEMA IF EXISTS auth CASCADE")
        connection.execute("DROP SERVER IF EXISTS auth_db_server CASCADE")
        puts "  ✓ Cleaned up partial setup"
      rescue => cleanup_error
        puts "  ⚠ Cleanup warning: #{cleanup_error.message}"
      end

      exit 1
    rescue => e
      puts "\n❌ FDW setup failed: #{e.message}"
      puts "   #{e.backtrace.first}"

      # Cleanup on failure
      begin
        connection.execute("DROP SCHEMA IF EXISTS auth CASCADE")
        connection.execute("DROP SERVER IF EXISTS auth_db_server CASCADE")
        puts "  ✓ Cleaned up partial setup"
      rescue => cleanup_error
        puts "  ⚠ Cleanup warning: #{cleanup_error.message}"
      end

      exit 1
    end
  end

  desc "Teardown FDW connection"
  task teardown: :environment do
    puts "Tearing down FDW connection..."

    connection = ActiveRecord::Base.connection

    begin
      connection.execute("DROP SCHEMA IF EXISTS auth CASCADE")
      puts "  ✓ auth schema dropped"

      connection.execute("DROP SERVER IF EXISTS auth_db_server CASCADE")
      puts "  ✓ Foreign server dropped"

      puts "\n✅ FDW teardown complete!"
    rescue => e
      puts "\n❌ FDW teardown failed: #{e.message}"
      puts "   #{e.backtrace.first}"
      exit 1
    end
  end

  desc "Test FDW connection"
  task test: :environment do
    puts "Testing FDW connection..."

    begin
      # Test users table
      result = ActiveRecord::Base.connection.execute("SELECT COUNT(*) as count FROM auth.users")
      user_count = result.first["count"]
      puts "  ✓ auth.users: #{user_count} records"

      # Test user_consents table
      result = ActiveRecord::Base.connection.execute("SELECT COUNT(*) as count FROM auth.user_consents")
      consent_count = result.first["count"]
      puts "  ✓ auth.user_consents: #{consent_count} records"

      # Test workspaces table
      result = ActiveRecord::Base.connection.execute("SELECT COUNT(*) as count FROM auth.workspaces")
      workspace_count = result.first["count"]
      puts "  ✓ auth.workspaces: #{workspace_count} records"

      # Test workspace_members table
      result = ActiveRecord::Base.connection.execute("SELECT COUNT(*) as count FROM auth.workspace_members")
      member_count = result.first["count"]
      puts "  ✓ auth.workspace_members: #{member_count} records"

      # Test Auth::User model
      first_user = Auth::User.first
      if first_user
        puts "  ✓ Auth::User.first: #{first_user.email}"
      else
        puts "  ⚠ No users found in Auth DB"
      end

      puts "\n✅ FDW test complete!"
    rescue => e
      puts "\n❌ FDW test failed: #{e.message}"
      puts "   Make sure to run 'rake fdw:setup' first"
      exit 1
    end
  end

  desc "Refresh FDW (teardown + setup)"
  task refresh: [ :teardown, :setup ] do
    puts "\n✅ FDW refresh complete!"
  end
end
