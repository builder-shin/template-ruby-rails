# frozen_string_literal: true

class ConvertToRailsConventions < ActiveRecord::Migration[8.1]
  def up
    # 1. VIEW 삭제 (의존성 제거)
    execute "DROP VIEW IF EXISTS career_hub_event_participant_summary CASCADE"

    # 2. Enum을 integer로 변환 (먼저! - enum 타입 의존성 제거)
    convert_enums_to_integers

    # 3. Enum 타입 삭제 (더 이상 사용되지 않음)
    drop_enum_types

    # 4. 컬럼명을 snake_case로 변환
    rename_columns_to_snake_case

    # 5. VIEW 재생성 (snake_case 컬럼 참조)
    recreate_view
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def rename_columns_to_snake_case
    # application_context_references
    safe_rename_column :application_context_references, :createdAt, :created_at
    safe_rename_column :application_context_references, :updatedAt, :updated_at
    safe_rename_column :application_context_references, :jobCategoryId, :job_category_id

    # career_hub_categories
    safe_rename_column :career_hub_categories, :categoryIdx, :category_idx
    safe_rename_column :career_hub_categories, :createdAt, :created_at
    safe_rename_column :career_hub_categories, :updatedAt, :updated_at
    safe_rename_column :career_hub_categories, :parentIdx, :parent_idx
    safe_rename_column :career_hub_categories, :displayOrder, :display_order
    safe_rename_column :career_hub_categories, :iconName, :icon_name
    safe_rename_column :career_hub_categories, :iconUrl, :icon_url
    safe_rename_column :career_hub_categories, :isVisible, :visible
    safe_rename_column :career_hub_categories, :isActive, :active
    safe_rename_column :career_hub_categories, :parentId, :parent_id

    # career_hub_communities
    safe_rename_column :career_hub_communities, :createdAt, :created_at
    safe_rename_column :career_hub_communities, :updatedAt, :updated_at
    safe_rename_column :career_hub_communities, :thumbnailUrl, :thumbnail_url
    safe_rename_column :career_hub_communities, :participantsCount, :participants_count
    safe_rename_column :career_hub_communities, :maxParticipants, :max_participants
    safe_rename_column :career_hub_communities, :introContent, :intro_content
    safe_rename_column :career_hub_communities, :joinPolicy, :join_policy
    safe_rename_column :career_hub_communities, :categoryId, :category_id
    safe_rename_column :career_hub_communities, :subcategoryId, :subcategory_id
    safe_rename_column :career_hub_communities, :leaderId, :leader_id
    safe_rename_column :career_hub_communities, :approvedAt, :approved_at
    safe_rename_column :career_hub_communities, :withdrawnAt, :withdrawn_at

    # career_hub_community_event_participants
    safe_rename_column :career_hub_community_event_participants, :createdAt, :created_at
    safe_rename_column :career_hub_community_event_participants, :updatedAt, :updated_at
    safe_rename_column :career_hub_community_event_participants, :eventId, :event_id
    safe_rename_column :career_hub_community_event_participants, :userId, :user_id

    # career_hub_community_events
    safe_rename_column :career_hub_community_events, :createdAt, :created_at
    safe_rename_column :career_hub_community_events, :updatedAt, :updated_at
    safe_rename_column :career_hub_community_events, :eventType, :event_type
    safe_rename_column :career_hub_community_events, :locationType, :location_type
    safe_rename_column :career_hub_community_events, :startAt, :start_at
    safe_rename_column :career_hub_community_events, :endAt, :end_at
    safe_rename_column :career_hub_community_events, :registrationStartAt, :registration_start_at
    safe_rename_column :career_hub_community_events, :registrationEndAt, :registration_end_at
    safe_rename_column :career_hub_community_events, :maxParticipants, :max_participants
    safe_rename_column :career_hub_community_events, :participantsCount, :participants_count
    safe_rename_column :career_hub_community_events, :publishAt, :publish_at
    safe_rename_column :career_hub_community_events, :meetingLink, :meeting_link
    safe_rename_column :career_hub_community_events, :thumbnailUrl, :thumbnail_url
    safe_rename_column :career_hub_community_events, :communityId, :community_id
    safe_rename_column :career_hub_community_events, :reviewNotificationSentAt, :review_notification_sent_at
    safe_rename_column :career_hub_community_events, :reviewReminderSentAt, :review_reminder_sent_at

    # career_hub_community_feed_likes
    safe_rename_column :career_hub_community_feed_likes, :createdAt, :created_at
    safe_rename_column :career_hub_community_feed_likes, :userId, :user_id
    safe_rename_column :career_hub_community_feed_likes, :feedId, :feed_id

    # career_hub_community_feeds
    safe_rename_column :career_hub_community_feeds, :createdAt, :created_at
    safe_rename_column :career_hub_community_feeds, :updatedAt, :updated_at
    safe_rename_column :career_hub_community_feeds, :communityId, :community_id
    safe_rename_column :career_hub_community_feeds, :authorId, :author_id
    safe_rename_column :career_hub_community_feeds, :parentId, :parent_id
    safe_rename_column :career_hub_community_feeds, :rootId, :root_id
    safe_rename_column :career_hub_community_feeds, :likesCount, :likes_count
    safe_rename_column :career_hub_community_feeds, :repliesCount, :replies_count
    safe_rename_column :career_hub_community_feeds, :isPinned, :pinned
    safe_rename_column :career_hub_community_feeds, :pinnedAt, :pinned_at
    safe_rename_column :career_hub_community_feeds, :contentEditedAt, :content_edited_at

    # career_hub_community_leaders
    safe_rename_column :career_hub_community_leaders, :createdAt, :created_at
    safe_rename_column :career_hub_community_leaders, :updatedAt, :updated_at
    safe_rename_column :career_hub_community_leaders, :displayName, :display_name
    safe_rename_column :career_hub_community_leaders, :avatarUrl, :avatar_url
    safe_rename_column :career_hub_community_leaders, :currentPosition, :current_position
    safe_rename_column :career_hub_community_leaders, :currentCompany, :current_company
    safe_rename_column :career_hub_community_leaders, :detailedBio, :detailed_bio
    safe_rename_column :career_hub_community_leaders, :verificationBadge, :verification_badge
    safe_rename_column :career_hub_community_leaders, :socialLinks, :social_links
    safe_rename_column :career_hub_community_leaders, :userId, :user_id

    # career_hub_community_members
    safe_rename_column :career_hub_community_members, :createdAt, :created_at
    safe_rename_column :career_hub_community_members, :updatedAt, :updated_at
    safe_rename_column :career_hub_community_members, :joinedAt, :joined_at
    safe_rename_column :career_hub_community_members, :communityId, :community_id
    safe_rename_column :career_hub_community_members, :userId, :user_id

    # career_hub_event_reviews
    safe_rename_column :career_hub_event_reviews, :createdAt, :created_at
    safe_rename_column :career_hub_event_reviews, :updatedAt, :updated_at
    safe_rename_column :career_hub_event_reviews, :deletedAt, :deleted_at
    safe_rename_column :career_hub_event_reviews, :eventId, :event_id
    safe_rename_column :career_hub_event_reviews, :userId, :user_id

    # countries
    safe_rename_column :countries, :createdAt, :created_at
    safe_rename_column :countries, :updatedAt, :updated_at

    # event_notification_schedules
    safe_rename_column :event_notification_schedules, :createdAt, :created_at
    safe_rename_column :event_notification_schedules, :updatedAt, :updated_at
    safe_rename_column :event_notification_schedules, :targetType, :target_type
    safe_rename_column :event_notification_schedules, :triggerType, :trigger_type
    safe_rename_column :event_notification_schedules, :triggerValue, :trigger_value
    safe_rename_column :event_notification_schedules, :sendTime, :send_time
    safe_rename_column :event_notification_schedules, :sendgridTemplateId, :sendgrid_template_id
    safe_rename_column :event_notification_schedules, :emailSubject, :email_subject
    safe_rename_column :event_notification_schedules, :isEnabled, :enabled
    safe_rename_column :event_notification_schedules, :lastExecutedAt, :last_executed_at

    # featured_profiles
    safe_rename_column :featured_profiles, :createdAt, :created_at
    safe_rename_column :featured_profiles, :updatedAt, :updated_at
    safe_rename_column :featured_profiles, :profileId, :profile_id
    safe_rename_column :featured_profiles, :displayOrder, :display_order

    # highlight_references
    safe_rename_column :highlight_references, :createdAt, :created_at
    safe_rename_column :highlight_references, :updatedAt, :updated_at
    safe_rename_column :highlight_references, :highlightType, :highlight_type
    safe_rename_column :highlight_references, :jobCategoryId, :job_category_id

    # job_applications
    safe_rename_column :job_applications, :createdAt, :created_at
    safe_rename_column :job_applications, :updatedAt, :updated_at
    safe_rename_column :job_applications, :jobPostId, :job_post_id
    safe_rename_column :job_applications, :profileId, :profile_id
    safe_rename_column :job_applications, :profileSnapshot, :profile_snapshot
    safe_rename_column :job_applications, :submittedAt, :submitted_at
    safe_rename_column :job_applications, :reviewedAt, :reviewed_at
    safe_rename_column :job_applications, :processedAt, :processed_at
    safe_rename_column :job_applications, :rejectionReason, :rejection_reason
    safe_rename_column :job_applications, :profileViewedAt, :profile_viewed_at

    # job_categories
    safe_rename_column :job_categories, :createdAt, :created_at
    safe_rename_column :job_categories, :updatedAt, :updated_at

    # job_post_categories
    safe_rename_column :job_post_categories, :jobPostId, :job_post_id
    safe_rename_column :job_post_categories, :jobCategoryId, :job_category_id

    # job_post_jobs
    safe_rename_column :job_post_jobs, :jobPostId, :job_post_id
    safe_rename_column :job_post_jobs, :jobId, :job_id

    # job_post_languages
    safe_rename_column :job_post_languages, :createdAt, :created_at
    safe_rename_column :job_post_languages, :updatedAt, :updated_at
    safe_rename_column :job_post_languages, :jobPostId, :job_post_id

    # job_post_status_logs
    safe_rename_column :job_post_status_logs, :jobPostId, :job_post_id
    safe_rename_column :job_post_status_logs, :fromStatus, :from_status
    safe_rename_column :job_post_status_logs, :toStatus, :to_status
    safe_rename_column :job_post_status_logs, :changedBy, :changed_by
    safe_rename_column :job_post_status_logs, :changedByType, :changed_by_type
    safe_rename_column :job_post_status_logs, :changedAt, :changed_at

    # job_posts
    safe_rename_column :job_posts, :createdAt, :created_at
    safe_rename_column :job_posts, :updatedAt, :updated_at
    safe_rename_column :job_posts, :workspaceId, :workspace_id
    safe_rename_column :job_posts, :employmentType, :employment_type
    safe_rename_column :job_posts, :experienceLevel, :experience_level
    safe_rename_column :job_posts, :languageRequired, :language_required
    safe_rename_column :job_posts, :contractConditions, :contract_conditions
    safe_rename_column :job_posts, :publicationType, :publication_type
    safe_rename_column :job_posts, :scheduledPublishDate, :scheduled_publish_date
    safe_rename_column :job_posts, :deadlineType, :deadline_type
    safe_rename_column :job_posts, :requestCount, :request_count
    safe_rename_column :job_posts, :rejectionReason, :rejection_reason
    safe_rename_column :job_posts, :viewCount, :view_count
    safe_rename_column :job_posts, :isPriority, :priority
    safe_rename_column :job_posts, :approvedAt, :approved_at
    safe_rename_column :job_posts, :approvedBy, :approved_by
    safe_rename_column :job_posts, :publishedAt, :published_at
    safe_rename_column :job_posts, :closedAt, :closed_at
    safe_rename_column :job_posts, :publishedSnapshot, :published_snapshot

    # jobs
    safe_rename_column :jobs, :createdAt, :created_at
    safe_rename_column :jobs, :updatedAt, :updated_at
    safe_rename_column :jobs, :jobCategoryId, :job_category_id

    # practical_strength_references
    safe_rename_column :practical_strength_references, :createdAt, :created_at
    safe_rename_column :practical_strength_references, :updatedAt, :updated_at
    safe_rename_column :practical_strength_references, :jobCategoryId, :job_category_id

    # profile_attachments
    safe_rename_column :profile_attachments, :createdAt, :created_at
    safe_rename_column :profile_attachments, :updatedAt, :updated_at
    safe_rename_column :profile_attachments, :profileId, :profile_id
    safe_rename_column :profile_attachments, :originalFileName, :original_file_name
    safe_rename_column :profile_attachments, :mimeType, :mime_type
    safe_rename_column :profile_attachments, :fileSize, :file_size
    safe_rename_column :profile_attachments, :sortOrder, :sort_order

    # profile_educations
    safe_rename_column :profile_educations, :createdAt, :created_at
    safe_rename_column :profile_educations, :updatedAt, :updated_at
    safe_rename_column :profile_educations, :educationLevel, :education_level
    safe_rename_column :profile_educations, :doubleMajor, :double_major
    safe_rename_column :profile_educations, :enrollmentDate, :enrollment_date
    safe_rename_column :profile_educations, :graduationDate, :graduation_date
    safe_rename_column :profile_educations, :profileId, :profile_id

    # profile_experiences
    safe_rename_column :profile_experiences, :createdAt, :created_at
    safe_rename_column :profile_experiences, :updatedAt, :updated_at
    safe_rename_column :profile_experiences, :startDate, :start_date
    safe_rename_column :profile_experiences, :endDate, :end_date
    safe_rename_column :profile_experiences, :isCurrent, :current
    safe_rename_column :profile_experiences, :workType, :work_type
    safe_rename_column :profile_experiences, :profileId, :profile_id

    # profile_freelance_experiences
    safe_rename_column :profile_freelance_experiences, :createdAt, :created_at
    safe_rename_column :profile_freelance_experiences, :updatedAt, :updated_at
    safe_rename_column :profile_freelance_experiences, :projectName, :project_name
    safe_rename_column :profile_freelance_experiences, :roleAndContribution, :role_and_contribution
    safe_rename_column :profile_freelance_experiences, :isRecurringContract, :recurring_contract
    safe_rename_column :profile_freelance_experiences, :projectStartDate, :project_start_date
    safe_rename_column :profile_freelance_experiences, :projectEndDate, :project_end_date
    safe_rename_column :profile_freelance_experiences, :workingHours, :working_hours
    safe_rename_column :profile_freelance_experiences, :weeklyHours, :weekly_hours
    safe_rename_column :profile_freelance_experiences, :workType, :work_type
    safe_rename_column :profile_freelance_experiences, :profileId, :profile_id

    # profile_highlights
    safe_rename_column :profile_highlights, :createdAt, :created_at
    safe_rename_column :profile_highlights, :updatedAt, :updated_at
    safe_rename_column :profile_highlights, :profileId, :profile_id

    # profile_jobs
    safe_rename_column :profile_jobs, :profileId, :profile_id
    safe_rename_column :profile_jobs, :jobId, :job_id

    # profile_languages
    safe_rename_column :profile_languages, :createdAt, :created_at
    safe_rename_column :profile_languages, :updatedAt, :updated_at
    safe_rename_column :profile_languages, :profileId, :profile_id

    # profile_links
    safe_rename_column :profile_links, :createdAt, :created_at
    safe_rename_column :profile_links, :updatedAt, :updated_at
    safe_rename_column :profile_links, :profileId, :profile_id

    # profile_projects
    safe_rename_column :profile_projects, :createdAt, :created_at
    safe_rename_column :profile_projects, :updatedAt, :updated_at
    safe_rename_column :profile_projects, :projectName, :project_name
    safe_rename_column :profile_projects, :backgroundOrGoal, :background_or_goal
    safe_rename_column :profile_projects, :projectStartDate, :project_start_date
    safe_rename_column :profile_projects, :projectEndDate, :project_end_date
    safe_rename_column :profile_projects, :workingHours, :working_hours
    safe_rename_column :profile_projects, :weeklyHours, :weekly_hours
    safe_rename_column :profile_projects, :profileId, :profile_id

    # profiles
    safe_rename_column :profiles, :createdAt, :created_at
    safe_rename_column :profiles, :updatedAt, :updated_at
    safe_rename_column :profiles, :userId, :user_id
    safe_rename_column :profiles, :profileImage, :profile_image
    safe_rename_column :profiles, :nationalityId, :nationality_id
    safe_rename_column :profiles, :employmentType, :employment_type
    safe_rename_column :profiles, :workType, :work_type
    safe_rename_column :profiles, :jobSeekingStatus, :job_seeking_status
    safe_rename_column :profiles, :startWork, :start_work
    safe_rename_column :profiles, :jobCategoryId, :job_category_id
    safe_rename_column :profiles, :practicalStrength, :practical_strength
    safe_rename_column :profiles, :problemSolvingAndExecution, :problem_solving_and_execution
    safe_rename_column :profiles, :collaborationAndCommunication, :collaboration_and_communication
    safe_rename_column :profiles, :isEmailPublic, :email_public
    safe_rename_column :profiles, :requiredCompleteness, :required_completeness
    safe_rename_column :profiles, :overallCompleteness, :overall_completeness
    safe_rename_column :profiles, :totalYearsOfExperience, :total_years_of_experience
  end

  def convert_enums_to_integers
    # career_hub_communities (camelCase: joinPolicy)
    convert_enum :career_hub_communities, :status, { "pending" => 0, "active" => 1, "inactive" => 2, "suspended" => 3 }
    convert_enum :career_hub_communities, :joinPolicy, { "open" => 0, "approval" => 1 }

    # career_hub_community_event_participants
    convert_enum :career_hub_community_event_participants, :status, {
      "registered" => 0, "confirmed" => 1, "cancelled" => 2, "attended" => 3, "no_show" => 4
    }

    # career_hub_community_events
    convert_enum :career_hub_community_events, :status, {
      "draft" => 0, "pending" => 1, "scheduled" => 2, "active" => 3,
      "completed" => 4, "closed" => 5, "cancelled" => 6, "suspended" => 7
    }

    # career_hub_community_feeds
    convert_enum :career_hub_community_feeds, :status, { "active" => 0, "deleted" => 1, "hidden" => 2 }

    # career_hub_community_leaders
    convert_enum :career_hub_community_leaders, :status, { "pending" => 0, "approved" => 1, "rejected" => 2, "suspended" => 3 }

    # career_hub_community_members
    convert_enum :career_hub_community_members, :status, { "pending" => 0, "active" => 1, "inactive" => 2, "banned" => 3 }

    # event_notification_schedules (camelCase: targetType, triggerType)
    convert_enum :event_notification_schedules, :targetType, { "community_event" => 0, "job_post" => 1 }
    convert_enum :event_notification_schedules, :triggerType, { "days_before" => 0, "hours_before" => 1 }

    # highlight_references (camelCase: highlightType)
    convert_enum :highlight_references, :highlightType, { "BEFORE" => 0, "ACTION" => 1, "AFTER" => 2 }

    # job_applications
    convert_enum :job_applications, :status, {
      "SUBMITTED" => 0, "UNDER_REVIEW" => 1, "DOCUMENT_PASSED" => 2,
      "ACCEPTED" => 3, "FINAL_PASSED" => 4, "REJECTED" => 5, "CANCELED" => 6
    }

    # job_post_languages / profile_languages
    proficiency_map = { "BASIC" => 0, "CONVERSATIONAL" => 1, "BUSINESS" => 2, "FLUENT" => 3, "NATIVE" => 4 }
    convert_enum :job_post_languages, :proficiency, proficiency_map
    convert_enum :profile_languages, :proficiency, proficiency_map

    # job_post_status_logs (camelCase: changedByType, fromStatus, toStatus)
    convert_enum :job_post_status_logs, :changedByType, { "ADMIN" => 0, "COMPANY" => 1, "SYSTEM" => 2 }

    job_post_status_map = {
      "DRAFT" => 0, "COMPLETED" => 1, "PENDING_REVIEW" => 2, "PENDING_PUBLISH" => 3,
      "RECRUITING" => 4, "CLOSED" => 5, "REJECTED" => 6, "COMPANY_STOPPED" => 7, "ADMIN_STOPPED" => 8
    }
    convert_enum :job_post_status_logs, :fromStatus, job_post_status_map
    convert_enum :job_post_status_logs, :toStatus, job_post_status_map

    # job_posts (camelCase: deadlineType, employmentType, experienceLevel, publicationType)
    convert_enum :job_posts, :status, job_post_status_map
    convert_enum :job_posts, :deadlineType, { "UNTIL_FILLED" => 0, "FIXED_DATE" => 1 }
    convert_enum :job_posts, :employmentType, { "FREELANCER" => 0, "CONTRACT" => 1, "FULL_TIME" => 2 }
    convert_enum :job_posts, :experienceLevel, {
      "UNDER_5_YEARS" => 0, "FROM_5_TO_10_YEARS" => 1, "FROM_10_TO_20_YEARS" => 2, "OVER_20_YEARS" => 3
    }
    convert_enum :job_posts, :publicationType, { "IMMEDIATE" => 0, "SCHEDULED" => 1 }

    # profile_educations (camelCase: educationLevel)
    convert_enum :profile_educations, :educationLevel, {
      "HIGH_SCHOOL" => 0, "COLLEGE" => 1, "UNIVERSITY" => 2,
      "MASTERS" => 3, "DOCTORATE" => 4, "INTEGRATED_MASTERS_DOCTORATE" => 5
    }
    convert_enum :profile_educations, :status, {
      "ENROLLED" => 0, "ON_LEAVE" => 1, "EXPECTED_GRADUATION" => 2,
      "GRADUATED" => 3, "COMPLETED" => 4, "DROPPED_OUT" => 5
    }

    # profile_experiences / profile_freelance_experiences (camelCase: workType)
    work_type_map = { "ON_SITE" => 0, "HYBRID" => 1, "REMOTE" => 2 }
    convert_enum :profile_experiences, :workType, work_type_map
    convert_enum :profile_freelance_experiences, :workType, work_type_map

    # profiles (camelCase: jobSeekingStatus, startWork)
    convert_enum :profiles, :jobSeekingStatus, { "ACTIVELY_SEEKING" => 0, "OPEN_TO_OFFERS" => 1, "NOT_SEEKING" => 2 }
    convert_enum :profiles, :startWork, {
      "WITHIN_ONE_WEEK" => 0, "WITHIN_ONE_MONTH" => 1, "ONE_MONTH_AFTER_OFFER" => 2, "NEGOTIABLE" => 3
    }
  end

  def safe_rename_column(table, from, to)
    rename_column table, from, to if column_exists?(table, from)
  end

  def convert_enum(table, column, mapping)
    # Use quoted column names for camelCase support
    quoted_column = connection.quote_column_name(column)
    temp_column = "#{column}_int"
    quoted_temp_column = connection.quote_column_name(temp_column)

    # Check if column exists (case-sensitive)
    unless connection.column_exists?(table, column)
      puts "Skipping #{table}.#{column} - column does not exist"
      return
    end

    # Add temp integer column
    execute "ALTER TABLE #{table} ADD COLUMN #{quoted_temp_column} integer"

    # Convert enum values to integers
    case_statements = mapping.map { |k, v| "WHEN '#{k}' THEN #{v}" }.join(" ")
    execute "UPDATE #{table} SET #{quoted_temp_column} = CASE #{quoted_column}::text #{case_statements} ELSE NULL END WHERE #{quoted_column} IS NOT NULL"

    # Drop original enum column
    execute "ALTER TABLE #{table} DROP COLUMN #{quoted_column}"

    # Rename temp column to original name (will be snake_case later via rename_columns_to_snake_case)
    execute "ALTER TABLE #{table} RENAME COLUMN #{quoted_temp_column} TO #{quoted_column}"
  end

  def drop_enum_types
    enum_types = %w[
      career_hub_communities_joinpolicy_enum career_hub_communities_status_enum
      career_hub_community_event_participants_status_enum career_hub_community_events_status_enum
      career_hub_community_feeds_status_enum career_hub_community_members_status_enum
      career_hub_leader_status_enum event_notification_target_type_enum
      event_notification_trigger_type_enum highlight_references_highlighttype_enum
      job_applications_status_enum job_post_status_logs_changedbytype_enum
      job_posts_deadlinetype_enum job_posts_employmenttype_enum
      job_posts_experiencelevel_enum job_posts_publicationtype_enum
      job_posts_status_enum language_proficiency_enum
      profile_educations_educationlevel_enum profile_educations_status_enum
      profile_experiences_worktype_enum profile_freelance_experiences_worktype_enum
      profiles_jobseekingstatus_enum profiles_startwork_enum
    ]
    enum_types.each { |t| execute "DROP TYPE IF EXISTS #{t} CASCADE" }
  end

  def recreate_view
    execute <<-SQL
      CREATE VIEW career_hub_event_participant_summary AS
      SELECT
        event_id,
        count(*) FILTER (WHERE status = 0)::integer AS registered,
        count(*) FILTER (WHERE status = 1)::integer AS confirmed,
        count(*) FILTER (WHERE status = 3)::integer AS attended,
        count(*) FILTER (WHERE status = 2)::integer AS cancelled,
        count(*) FILTER (WHERE status = 4)::integer AS no_show,
        count(*)::integer AS total
      FROM career_hub_community_event_participants
      GROUP BY event_id
    SQL
  end
end
