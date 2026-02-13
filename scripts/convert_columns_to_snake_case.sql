-- ============================================================
-- TypeORM camelCase → Rails snake_case 컬럼명 변환 스크립트
-- 작성일: 2026-02-04
-- 대상: 모든 camelCase 컬럼
-- ============================================================

BEGIN;

-- ============================================================
-- 1. VIEW 삭제 (의존성 제거)
-- ============================================================
DROP VIEW IF EXISTS career_hub_event_participant_summary CASCADE;

-- ============================================================
-- 2. Profile 관련 테이블
-- ============================================================

-- profiles (이미 변환된 경우 스킵)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'createdAt') THEN
    ALTER TABLE profiles RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'updatedAt') THEN
    ALTER TABLE profiles RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'userId') THEN
    ALTER TABLE profiles RENAME COLUMN "userId" TO user_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'profileImage') THEN
    ALTER TABLE profiles RENAME COLUMN "profileImage" TO profile_image;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'nationalityId') THEN
    ALTER TABLE profiles RENAME COLUMN "nationalityId" TO nationality_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'employmentType') THEN
    ALTER TABLE profiles RENAME COLUMN "employmentType" TO employment_type;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'workType') THEN
    ALTER TABLE profiles RENAME COLUMN "workType" TO work_type;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'jobSeekingStatus') THEN
    ALTER TABLE profiles RENAME COLUMN "jobSeekingStatus" TO job_seeking_status;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'startWork') THEN
    ALTER TABLE profiles RENAME COLUMN "startWork" TO start_work;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'jobCategoryId') THEN
    ALTER TABLE profiles RENAME COLUMN "jobCategoryId" TO job_category_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'practicalStrength') THEN
    ALTER TABLE profiles RENAME COLUMN "practicalStrength" TO practical_strength;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'problemSolvingAndExecution') THEN
    ALTER TABLE profiles RENAME COLUMN "problemSolvingAndExecution" TO problem_solving_and_execution;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'collaborationAndCommunication') THEN
    ALTER TABLE profiles RENAME COLUMN "collaborationAndCommunication" TO collaboration_and_communication;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'isEmailPublic') THEN
    ALTER TABLE profiles RENAME COLUMN "isEmailPublic" TO email_public;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'requiredCompleteness') THEN
    ALTER TABLE profiles RENAME COLUMN "requiredCompleteness" TO required_completeness;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'overallCompleteness') THEN
    ALTER TABLE profiles RENAME COLUMN "overallCompleteness" TO overall_completeness;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'totalYearsOfExperience') THEN
    ALTER TABLE profiles RENAME COLUMN "totalYearsOfExperience" TO total_years_of_experience;
  END IF;
END $$;

-- featured_profiles
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'featured_profiles' AND column_name = 'createdAt') THEN
    ALTER TABLE featured_profiles RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'featured_profiles' AND column_name = 'updatedAt') THEN
    ALTER TABLE featured_profiles RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'featured_profiles' AND column_name = 'profileId') THEN
    ALTER TABLE featured_profiles RENAME COLUMN "profileId" TO profile_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'featured_profiles' AND column_name = 'displayOrder') THEN
    ALTER TABLE featured_profiles RENAME COLUMN "displayOrder" TO display_order;
  END IF;
END $$;

-- profile_jobs
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_jobs' AND column_name = 'profileId') THEN
    ALTER TABLE profile_jobs RENAME COLUMN "profileId" TO profile_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_jobs' AND column_name = 'jobId') THEN
    ALTER TABLE profile_jobs RENAME COLUMN "jobId" TO job_id;
  END IF;
END $$;

-- profile_experiences
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_experiences' AND column_name = 'createdAt') THEN
    ALTER TABLE profile_experiences RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_experiences' AND column_name = 'updatedAt') THEN
    ALTER TABLE profile_experiences RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_experiences' AND column_name = 'startDate') THEN
    ALTER TABLE profile_experiences RENAME COLUMN "startDate" TO start_date;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_experiences' AND column_name = 'endDate') THEN
    ALTER TABLE profile_experiences RENAME COLUMN "endDate" TO end_date;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_experiences' AND column_name = 'isCurrent') THEN
    ALTER TABLE profile_experiences RENAME COLUMN "isCurrent" TO current;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_experiences' AND column_name = 'workType') THEN
    ALTER TABLE profile_experiences RENAME COLUMN "workType" TO work_type;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_experiences' AND column_name = 'profileId') THEN
    ALTER TABLE profile_experiences RENAME COLUMN "profileId" TO profile_id;
  END IF;
END $$;

-- profile_educations
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_educations' AND column_name = 'createdAt') THEN
    ALTER TABLE profile_educations RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_educations' AND column_name = 'updatedAt') THEN
    ALTER TABLE profile_educations RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_educations' AND column_name = 'educationLevel') THEN
    ALTER TABLE profile_educations RENAME COLUMN "educationLevel" TO education_level;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_educations' AND column_name = 'doubleMajor') THEN
    ALTER TABLE profile_educations RENAME COLUMN "doubleMajor" TO double_major;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_educations' AND column_name = 'enrollmentDate') THEN
    ALTER TABLE profile_educations RENAME COLUMN "enrollmentDate" TO enrollment_date;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_educations' AND column_name = 'graduationDate') THEN
    ALTER TABLE profile_educations RENAME COLUMN "graduationDate" TO graduation_date;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_educations' AND column_name = 'profileId') THEN
    ALTER TABLE profile_educations RENAME COLUMN "profileId" TO profile_id;
  END IF;
END $$;

-- profile_freelance_experiences
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_freelance_experiences' AND column_name = 'createdAt') THEN
    ALTER TABLE profile_freelance_experiences RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_freelance_experiences' AND column_name = 'updatedAt') THEN
    ALTER TABLE profile_freelance_experiences RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_freelance_experiences' AND column_name = 'projectName') THEN
    ALTER TABLE profile_freelance_experiences RENAME COLUMN "projectName" TO project_name;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_freelance_experiences' AND column_name = 'roleAndContribution') THEN
    ALTER TABLE profile_freelance_experiences RENAME COLUMN "roleAndContribution" TO role_and_contribution;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_freelance_experiences' AND column_name = 'isRecurringContract') THEN
    ALTER TABLE profile_freelance_experiences RENAME COLUMN "isRecurringContract" TO recurring_contract;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_freelance_experiences' AND column_name = 'projectStartDate') THEN
    ALTER TABLE profile_freelance_experiences RENAME COLUMN "projectStartDate" TO project_start_date;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_freelance_experiences' AND column_name = 'projectEndDate') THEN
    ALTER TABLE profile_freelance_experiences RENAME COLUMN "projectEndDate" TO project_end_date;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_freelance_experiences' AND column_name = 'workingHours') THEN
    ALTER TABLE profile_freelance_experiences RENAME COLUMN "workingHours" TO working_hours;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_freelance_experiences' AND column_name = 'weeklyHours') THEN
    ALTER TABLE profile_freelance_experiences RENAME COLUMN "weeklyHours" TO weekly_hours;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_freelance_experiences' AND column_name = 'workType') THEN
    ALTER TABLE profile_freelance_experiences RENAME COLUMN "workType" TO work_type;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_freelance_experiences' AND column_name = 'profileId') THEN
    ALTER TABLE profile_freelance_experiences RENAME COLUMN "profileId" TO profile_id;
  END IF;
END $$;

-- profile_highlights
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_highlights' AND column_name = 'createdAt') THEN
    ALTER TABLE profile_highlights RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_highlights' AND column_name = 'updatedAt') THEN
    ALTER TABLE profile_highlights RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_highlights' AND column_name = 'profileId') THEN
    ALTER TABLE profile_highlights RENAME COLUMN "profileId" TO profile_id;
  END IF;
END $$;

-- profile_languages
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_languages' AND column_name = 'createdAt') THEN
    ALTER TABLE profile_languages RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_languages' AND column_name = 'updatedAt') THEN
    ALTER TABLE profile_languages RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_languages' AND column_name = 'profileId') THEN
    ALTER TABLE profile_languages RENAME COLUMN "profileId" TO profile_id;
  END IF;
END $$;

-- profile_links
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_links' AND column_name = 'createdAt') THEN
    ALTER TABLE profile_links RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_links' AND column_name = 'updatedAt') THEN
    ALTER TABLE profile_links RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_links' AND column_name = 'profileId') THEN
    ALTER TABLE profile_links RENAME COLUMN "profileId" TO profile_id;
  END IF;
END $$;

-- profile_projects
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_projects' AND column_name = 'createdAt') THEN
    ALTER TABLE profile_projects RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_projects' AND column_name = 'updatedAt') THEN
    ALTER TABLE profile_projects RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_projects' AND column_name = 'projectName') THEN
    ALTER TABLE profile_projects RENAME COLUMN "projectName" TO project_name;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_projects' AND column_name = 'backgroundOrGoal') THEN
    ALTER TABLE profile_projects RENAME COLUMN "backgroundOrGoal" TO background_or_goal;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_projects' AND column_name = 'projectStartDate') THEN
    ALTER TABLE profile_projects RENAME COLUMN "projectStartDate" TO project_start_date;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_projects' AND column_name = 'projectEndDate') THEN
    ALTER TABLE profile_projects RENAME COLUMN "projectEndDate" TO project_end_date;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_projects' AND column_name = 'workingHours') THEN
    ALTER TABLE profile_projects RENAME COLUMN "workingHours" TO working_hours;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_projects' AND column_name = 'weeklyHours') THEN
    ALTER TABLE profile_projects RENAME COLUMN "weeklyHours" TO weekly_hours;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_projects' AND column_name = 'profileId') THEN
    ALTER TABLE profile_projects RENAME COLUMN "profileId" TO profile_id;
  END IF;
END $$;

-- profile_attachments
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_attachments' AND column_name = 'createdAt') THEN
    ALTER TABLE profile_attachments RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_attachments' AND column_name = 'updatedAt') THEN
    ALTER TABLE profile_attachments RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_attachments' AND column_name = 'profileId') THEN
    ALTER TABLE profile_attachments RENAME COLUMN "profileId" TO profile_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_attachments' AND column_name = 'originalFileName') THEN
    ALTER TABLE profile_attachments RENAME COLUMN "originalFileName" TO original_file_name;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_attachments' AND column_name = 'mimeType') THEN
    ALTER TABLE profile_attachments RENAME COLUMN "mimeType" TO mime_type;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_attachments' AND column_name = 'fileSize') THEN
    ALTER TABLE profile_attachments RENAME COLUMN "fileSize" TO file_size;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profile_attachments' AND column_name = 'sortOrder') THEN
    ALTER TABLE profile_attachments RENAME COLUMN "sortOrder" TO sort_order;
  END IF;
END $$;

-- ============================================================
-- 3. Job 관련 테이블
-- ============================================================

-- job_posts
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'createdAt') THEN
    ALTER TABLE job_posts RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'updatedAt') THEN
    ALTER TABLE job_posts RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'workspaceId') THEN
    ALTER TABLE job_posts RENAME COLUMN "workspaceId" TO workspace_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'employmentType') THEN
    ALTER TABLE job_posts RENAME COLUMN "employmentType" TO employment_type;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'experienceLevel') THEN
    ALTER TABLE job_posts RENAME COLUMN "experienceLevel" TO experience_level;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'languageRequired') THEN
    ALTER TABLE job_posts RENAME COLUMN "languageRequired" TO language_required;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'contractConditions') THEN
    ALTER TABLE job_posts RENAME COLUMN "contractConditions" TO contract_conditions;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'publicationType') THEN
    ALTER TABLE job_posts RENAME COLUMN "publicationType" TO publication_type;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'scheduledPublishDate') THEN
    ALTER TABLE job_posts RENAME COLUMN "scheduledPublishDate" TO scheduled_publish_date;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'deadlineType') THEN
    ALTER TABLE job_posts RENAME COLUMN "deadlineType" TO deadline_type;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'requestCount') THEN
    ALTER TABLE job_posts RENAME COLUMN "requestCount" TO request_count;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'rejectionReason') THEN
    ALTER TABLE job_posts RENAME COLUMN "rejectionReason" TO rejection_reason;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'viewCount') THEN
    ALTER TABLE job_posts RENAME COLUMN "viewCount" TO view_count;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'isPriority') THEN
    ALTER TABLE job_posts RENAME COLUMN "isPriority" TO priority;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'approvedAt') THEN
    ALTER TABLE job_posts RENAME COLUMN "approvedAt" TO approved_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'approvedBy') THEN
    ALTER TABLE job_posts RENAME COLUMN "approvedBy" TO approved_by;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'publishedAt') THEN
    ALTER TABLE job_posts RENAME COLUMN "publishedAt" TO published_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'closedAt') THEN
    ALTER TABLE job_posts RENAME COLUMN "closedAt" TO closed_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_posts' AND column_name = 'publishedSnapshot') THEN
    ALTER TABLE job_posts RENAME COLUMN "publishedSnapshot" TO published_snapshot;
  END IF;
END $$;

-- job_applications
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_applications' AND column_name = 'createdAt') THEN
    ALTER TABLE job_applications RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_applications' AND column_name = 'updatedAt') THEN
    ALTER TABLE job_applications RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_applications' AND column_name = 'jobPostId') THEN
    ALTER TABLE job_applications RENAME COLUMN "jobPostId" TO job_post_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_applications' AND column_name = 'profileId') THEN
    ALTER TABLE job_applications RENAME COLUMN "profileId" TO profile_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_applications' AND column_name = 'profileSnapshot') THEN
    ALTER TABLE job_applications RENAME COLUMN "profileSnapshot" TO profile_snapshot;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_applications' AND column_name = 'submittedAt') THEN
    ALTER TABLE job_applications RENAME COLUMN "submittedAt" TO submitted_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_applications' AND column_name = 'reviewedAt') THEN
    ALTER TABLE job_applications RENAME COLUMN "reviewedAt" TO reviewed_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_applications' AND column_name = 'processedAt') THEN
    ALTER TABLE job_applications RENAME COLUMN "processedAt" TO processed_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_applications' AND column_name = 'rejectionReason') THEN
    ALTER TABLE job_applications RENAME COLUMN "rejectionReason" TO rejection_reason;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_applications' AND column_name = 'profileViewedAt') THEN
    ALTER TABLE job_applications RENAME COLUMN "profileViewedAt" TO profile_viewed_at;
  END IF;
END $$;

-- job_categories
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_categories' AND column_name = 'createdAt') THEN
    ALTER TABLE job_categories RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_categories' AND column_name = 'updatedAt') THEN
    ALTER TABLE job_categories RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;

-- job_post_categories
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_post_categories' AND column_name = 'jobPostId') THEN
    ALTER TABLE job_post_categories RENAME COLUMN "jobPostId" TO job_post_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_post_categories' AND column_name = 'jobCategoryId') THEN
    ALTER TABLE job_post_categories RENAME COLUMN "jobCategoryId" TO job_category_id;
  END IF;
END $$;

-- job_post_jobs
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_post_jobs' AND column_name = 'jobPostId') THEN
    ALTER TABLE job_post_jobs RENAME COLUMN "jobPostId" TO job_post_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_post_jobs' AND column_name = 'jobId') THEN
    ALTER TABLE job_post_jobs RENAME COLUMN "jobId" TO job_id;
  END IF;
END $$;

-- job_post_languages
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_post_languages' AND column_name = 'createdAt') THEN
    ALTER TABLE job_post_languages RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_post_languages' AND column_name = 'updatedAt') THEN
    ALTER TABLE job_post_languages RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_post_languages' AND column_name = 'jobPostId') THEN
    ALTER TABLE job_post_languages RENAME COLUMN "jobPostId" TO job_post_id;
  END IF;
END $$;

-- job_post_status_logs
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_post_status_logs' AND column_name = 'jobPostId') THEN
    ALTER TABLE job_post_status_logs RENAME COLUMN "jobPostId" TO job_post_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_post_status_logs' AND column_name = 'fromStatus') THEN
    ALTER TABLE job_post_status_logs RENAME COLUMN "fromStatus" TO from_status;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_post_status_logs' AND column_name = 'toStatus') THEN
    ALTER TABLE job_post_status_logs RENAME COLUMN "toStatus" TO to_status;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_post_status_logs' AND column_name = 'changedBy') THEN
    ALTER TABLE job_post_status_logs RENAME COLUMN "changedBy" TO changed_by;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_post_status_logs' AND column_name = 'changedByType') THEN
    ALTER TABLE job_post_status_logs RENAME COLUMN "changedByType" TO changed_by_type;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_post_status_logs' AND column_name = 'changedAt') THEN
    ALTER TABLE job_post_status_logs RENAME COLUMN "changedAt" TO changed_at;
  END IF;
END $$;

-- jobs
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'jobs' AND column_name = 'createdAt') THEN
    ALTER TABLE jobs RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'jobs' AND column_name = 'updatedAt') THEN
    ALTER TABLE jobs RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'jobs' AND column_name = 'jobCategoryId') THEN
    ALTER TABLE jobs RENAME COLUMN "jobCategoryId" TO job_category_id;
  END IF;
END $$;

-- ============================================================
-- 4. Career Hub 관련 테이블
-- ============================================================

-- career_hub_categories
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_categories' AND column_name = 'categoryIdx') THEN
    ALTER TABLE career_hub_categories RENAME COLUMN "categoryIdx" TO category_idx;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_categories' AND column_name = 'createdAt') THEN
    ALTER TABLE career_hub_categories RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_categories' AND column_name = 'updatedAt') THEN
    ALTER TABLE career_hub_categories RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_categories' AND column_name = 'parentIdx') THEN
    ALTER TABLE career_hub_categories RENAME COLUMN "parentIdx" TO parent_idx;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_categories' AND column_name = 'displayOrder') THEN
    ALTER TABLE career_hub_categories RENAME COLUMN "displayOrder" TO display_order;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_categories' AND column_name = 'iconName') THEN
    ALTER TABLE career_hub_categories RENAME COLUMN "iconName" TO icon_name;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_categories' AND column_name = 'iconUrl') THEN
    ALTER TABLE career_hub_categories RENAME COLUMN "iconUrl" TO icon_url;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_categories' AND column_name = 'isVisible') THEN
    ALTER TABLE career_hub_categories RENAME COLUMN "isVisible" TO visible;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_categories' AND column_name = 'isActive') THEN
    ALTER TABLE career_hub_categories RENAME COLUMN "isActive" TO active;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_categories' AND column_name = 'parentId') THEN
    ALTER TABLE career_hub_categories RENAME COLUMN "parentId" TO parent_id;
  END IF;
END $$;

-- career_hub_communities
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_communities' AND column_name = 'createdAt') THEN
    ALTER TABLE career_hub_communities RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_communities' AND column_name = 'updatedAt') THEN
    ALTER TABLE career_hub_communities RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_communities' AND column_name = 'thumbnailUrl') THEN
    ALTER TABLE career_hub_communities RENAME COLUMN "thumbnailUrl" TO thumbnail_url;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_communities' AND column_name = 'participantsCount') THEN
    ALTER TABLE career_hub_communities RENAME COLUMN "participantsCount" TO participants_count;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_communities' AND column_name = 'maxParticipants') THEN
    ALTER TABLE career_hub_communities RENAME COLUMN "maxParticipants" TO max_participants;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_communities' AND column_name = 'introContent') THEN
    ALTER TABLE career_hub_communities RENAME COLUMN "introContent" TO intro_content;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_communities' AND column_name = 'joinPolicy') THEN
    ALTER TABLE career_hub_communities RENAME COLUMN "joinPolicy" TO join_policy;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_communities' AND column_name = 'categoryId') THEN
    ALTER TABLE career_hub_communities RENAME COLUMN "categoryId" TO category_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_communities' AND column_name = 'subcategoryId') THEN
    ALTER TABLE career_hub_communities RENAME COLUMN "subcategoryId" TO subcategory_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_communities' AND column_name = 'leaderId') THEN
    ALTER TABLE career_hub_communities RENAME COLUMN "leaderId" TO leader_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_communities' AND column_name = 'approvedAt') THEN
    ALTER TABLE career_hub_communities RENAME COLUMN "approvedAt" TO approved_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_communities' AND column_name = 'withdrawnAt') THEN
    ALTER TABLE career_hub_communities RENAME COLUMN "withdrawnAt" TO withdrawn_at;
  END IF;
END $$;

-- career_hub_community_event_participants
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_event_participants' AND column_name = 'createdAt') THEN
    ALTER TABLE career_hub_community_event_participants RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_event_participants' AND column_name = 'updatedAt') THEN
    ALTER TABLE career_hub_community_event_participants RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_event_participants' AND column_name = 'eventId') THEN
    ALTER TABLE career_hub_community_event_participants RENAME COLUMN "eventId" TO event_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_event_participants' AND column_name = 'userId') THEN
    ALTER TABLE career_hub_community_event_participants RENAME COLUMN "userId" TO user_id;
  END IF;
END $$;

-- career_hub_community_events
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_events' AND column_name = 'createdAt') THEN
    ALTER TABLE career_hub_community_events RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_events' AND column_name = 'updatedAt') THEN
    ALTER TABLE career_hub_community_events RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_events' AND column_name = 'eventType') THEN
    ALTER TABLE career_hub_community_events RENAME COLUMN "eventType" TO event_type;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_events' AND column_name = 'locationType') THEN
    ALTER TABLE career_hub_community_events RENAME COLUMN "locationType" TO location_type;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_events' AND column_name = 'startAt') THEN
    ALTER TABLE career_hub_community_events RENAME COLUMN "startAt" TO start_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_events' AND column_name = 'endAt') THEN
    ALTER TABLE career_hub_community_events RENAME COLUMN "endAt" TO end_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_events' AND column_name = 'registrationStartAt') THEN
    ALTER TABLE career_hub_community_events RENAME COLUMN "registrationStartAt" TO registration_start_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_events' AND column_name = 'registrationEndAt') THEN
    ALTER TABLE career_hub_community_events RENAME COLUMN "registrationEndAt" TO registration_end_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_events' AND column_name = 'maxParticipants') THEN
    ALTER TABLE career_hub_community_events RENAME COLUMN "maxParticipants" TO max_participants;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_events' AND column_name = 'participantsCount') THEN
    ALTER TABLE career_hub_community_events RENAME COLUMN "participantsCount" TO participants_count;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_events' AND column_name = 'publishAt') THEN
    ALTER TABLE career_hub_community_events RENAME COLUMN "publishAt" TO publish_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_events' AND column_name = 'meetingLink') THEN
    ALTER TABLE career_hub_community_events RENAME COLUMN "meetingLink" TO meeting_link;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_events' AND column_name = 'thumbnailUrl') THEN
    ALTER TABLE career_hub_community_events RENAME COLUMN "thumbnailUrl" TO thumbnail_url;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_events' AND column_name = 'communityId') THEN
    ALTER TABLE career_hub_community_events RENAME COLUMN "communityId" TO community_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_events' AND column_name = 'reviewNotificationSentAt') THEN
    ALTER TABLE career_hub_community_events RENAME COLUMN "reviewNotificationSentAt" TO review_notification_sent_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_events' AND column_name = 'reviewReminderSentAt') THEN
    ALTER TABLE career_hub_community_events RENAME COLUMN "reviewReminderSentAt" TO review_reminder_sent_at;
  END IF;
END $$;

-- career_hub_community_feed_likes
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_feed_likes' AND column_name = 'createdAt') THEN
    ALTER TABLE career_hub_community_feed_likes RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_feed_likes' AND column_name = 'userId') THEN
    ALTER TABLE career_hub_community_feed_likes RENAME COLUMN "userId" TO user_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_feed_likes' AND column_name = 'feedId') THEN
    ALTER TABLE career_hub_community_feed_likes RENAME COLUMN "feedId" TO feed_id;
  END IF;
END $$;

-- career_hub_community_feeds
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_feeds' AND column_name = 'createdAt') THEN
    ALTER TABLE career_hub_community_feeds RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_feeds' AND column_name = 'updatedAt') THEN
    ALTER TABLE career_hub_community_feeds RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_feeds' AND column_name = 'communityId') THEN
    ALTER TABLE career_hub_community_feeds RENAME COLUMN "communityId" TO community_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_feeds' AND column_name = 'authorId') THEN
    ALTER TABLE career_hub_community_feeds RENAME COLUMN "authorId" TO author_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_feeds' AND column_name = 'parentId') THEN
    ALTER TABLE career_hub_community_feeds RENAME COLUMN "parentId" TO parent_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_feeds' AND column_name = 'rootId') THEN
    ALTER TABLE career_hub_community_feeds RENAME COLUMN "rootId" TO root_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_feeds' AND column_name = 'likesCount') THEN
    ALTER TABLE career_hub_community_feeds RENAME COLUMN "likesCount" TO likes_count;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_feeds' AND column_name = 'repliesCount') THEN
    ALTER TABLE career_hub_community_feeds RENAME COLUMN "repliesCount" TO replies_count;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_feeds' AND column_name = 'isPinned') THEN
    ALTER TABLE career_hub_community_feeds RENAME COLUMN "isPinned" TO pinned;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_feeds' AND column_name = 'pinnedAt') THEN
    ALTER TABLE career_hub_community_feeds RENAME COLUMN "pinnedAt" TO pinned_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_feeds' AND column_name = 'contentEditedAt') THEN
    ALTER TABLE career_hub_community_feeds RENAME COLUMN "contentEditedAt" TO content_edited_at;
  END IF;
END $$;

-- career_hub_community_leaders
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_leaders' AND column_name = 'createdAt') THEN
    ALTER TABLE career_hub_community_leaders RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_leaders' AND column_name = 'updatedAt') THEN
    ALTER TABLE career_hub_community_leaders RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_leaders' AND column_name = 'displayName') THEN
    ALTER TABLE career_hub_community_leaders RENAME COLUMN "displayName" TO display_name;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_leaders' AND column_name = 'avatarUrl') THEN
    ALTER TABLE career_hub_community_leaders RENAME COLUMN "avatarUrl" TO avatar_url;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_leaders' AND column_name = 'currentPosition') THEN
    ALTER TABLE career_hub_community_leaders RENAME COLUMN "currentPosition" TO current_position;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_leaders' AND column_name = 'currentCompany') THEN
    ALTER TABLE career_hub_community_leaders RENAME COLUMN "currentCompany" TO current_company;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_leaders' AND column_name = 'detailedBio') THEN
    ALTER TABLE career_hub_community_leaders RENAME COLUMN "detailedBio" TO detailed_bio;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_leaders' AND column_name = 'verificationBadge') THEN
    ALTER TABLE career_hub_community_leaders RENAME COLUMN "verificationBadge" TO verification_badge;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_leaders' AND column_name = 'socialLinks') THEN
    ALTER TABLE career_hub_community_leaders RENAME COLUMN "socialLinks" TO social_links;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_leaders' AND column_name = 'userId') THEN
    ALTER TABLE career_hub_community_leaders RENAME COLUMN "userId" TO user_id;
  END IF;
END $$;

-- career_hub_community_members
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_members' AND column_name = 'createdAt') THEN
    ALTER TABLE career_hub_community_members RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_members' AND column_name = 'updatedAt') THEN
    ALTER TABLE career_hub_community_members RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_members' AND column_name = 'joinedAt') THEN
    ALTER TABLE career_hub_community_members RENAME COLUMN "joinedAt" TO joined_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_members' AND column_name = 'communityId') THEN
    ALTER TABLE career_hub_community_members RENAME COLUMN "communityId" TO community_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_members' AND column_name = 'userId') THEN
    ALTER TABLE career_hub_community_members RENAME COLUMN "userId" TO user_id;
  END IF;
END $$;

-- career_hub_event_reviews
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_event_reviews' AND column_name = 'createdAt') THEN
    ALTER TABLE career_hub_event_reviews RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_event_reviews' AND column_name = 'updatedAt') THEN
    ALTER TABLE career_hub_event_reviews RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_event_reviews' AND column_name = 'deletedAt') THEN
    ALTER TABLE career_hub_event_reviews RENAME COLUMN "deletedAt" TO deleted_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_event_reviews' AND column_name = 'eventId') THEN
    ALTER TABLE career_hub_event_reviews RENAME COLUMN "eventId" TO event_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_event_reviews' AND column_name = 'userId') THEN
    ALTER TABLE career_hub_event_reviews RENAME COLUMN "userId" TO user_id;
  END IF;
END $$;

-- ============================================================
-- 5. 기타 테이블
-- ============================================================

-- countries
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'countries' AND column_name = 'createdAt') THEN
    ALTER TABLE countries RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'countries' AND column_name = 'updatedAt') THEN
    ALTER TABLE countries RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;

-- application_context_references
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'application_context_references' AND column_name = 'createdAt') THEN
    ALTER TABLE application_context_references RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'application_context_references' AND column_name = 'updatedAt') THEN
    ALTER TABLE application_context_references RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'application_context_references' AND column_name = 'jobCategoryId') THEN
    ALTER TABLE application_context_references RENAME COLUMN "jobCategoryId" TO job_category_id;
  END IF;
END $$;

-- highlight_references
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'highlight_references' AND column_name = 'createdAt') THEN
    ALTER TABLE highlight_references RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'highlight_references' AND column_name = 'updatedAt') THEN
    ALTER TABLE highlight_references RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'highlight_references' AND column_name = 'highlightType') THEN
    ALTER TABLE highlight_references RENAME COLUMN "highlightType" TO highlight_type;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'highlight_references' AND column_name = 'jobCategoryId') THEN
    ALTER TABLE highlight_references RENAME COLUMN "jobCategoryId" TO job_category_id;
  END IF;
END $$;

-- practical_strength_references
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'practical_strength_references' AND column_name = 'createdAt') THEN
    ALTER TABLE practical_strength_references RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'practical_strength_references' AND column_name = 'updatedAt') THEN
    ALTER TABLE practical_strength_references RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'practical_strength_references' AND column_name = 'jobCategoryId') THEN
    ALTER TABLE practical_strength_references RENAME COLUMN "jobCategoryId" TO job_category_id;
  END IF;
END $$;

-- event_notification_schedules
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'event_notification_schedules' AND column_name = 'createdAt') THEN
    ALTER TABLE event_notification_schedules RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'event_notification_schedules' AND column_name = 'updatedAt') THEN
    ALTER TABLE event_notification_schedules RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'event_notification_schedules' AND column_name = 'targetType') THEN
    ALTER TABLE event_notification_schedules RENAME COLUMN "targetType" TO target_type;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'event_notification_schedules' AND column_name = 'triggerType') THEN
    ALTER TABLE event_notification_schedules RENAME COLUMN "triggerType" TO trigger_type;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'event_notification_schedules' AND column_name = 'triggerValue') THEN
    ALTER TABLE event_notification_schedules RENAME COLUMN "triggerValue" TO trigger_value;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'event_notification_schedules' AND column_name = 'sendTime') THEN
    ALTER TABLE event_notification_schedules RENAME COLUMN "sendTime" TO send_time;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'event_notification_schedules' AND column_name = 'sendgridTemplateId') THEN
    ALTER TABLE event_notification_schedules RENAME COLUMN "sendgridTemplateId" TO sendgrid_template_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'event_notification_schedules' AND column_name = 'emailSubject') THEN
    ALTER TABLE event_notification_schedules RENAME COLUMN "emailSubject" TO email_subject;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'event_notification_schedules' AND column_name = 'isEnabled') THEN
    ALTER TABLE event_notification_schedules RENAME COLUMN "isEnabled" TO enabled;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'event_notification_schedules' AND column_name = 'lastExecutedAt') THEN
    ALTER TABLE event_notification_schedules RENAME COLUMN "lastExecutedAt" TO last_executed_at;
  END IF;
END $$;

-- blog_author_permission
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_author_permission' AND column_name = 'createdAt') THEN
    ALTER TABLE blog_author_permission RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_author_permission' AND column_name = 'updatedAt') THEN
    ALTER TABLE blog_author_permission RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_author_permission' AND column_name = 'authorId') THEN
    ALTER TABLE blog_author_permission RENAME COLUMN "authorId" TO author_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_author_permission' AND column_name = 'authorType') THEN
    ALTER TABLE blog_author_permission RENAME COLUMN "authorType" TO author_type;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_author_permission' AND column_name = 'requestedAt') THEN
    ALTER TABLE blog_author_permission RENAME COLUMN "requestedAt" TO requested_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_author_permission' AND column_name = 'processedAt') THEN
    ALTER TABLE blog_author_permission RENAME COLUMN "processedAt" TO processed_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_author_permission' AND column_name = 'processedBy') THEN
    ALTER TABLE blog_author_permission RENAME COLUMN "processedBy" TO processed_by;
  END IF;
END $$;

-- blog_category
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_category' AND column_name = 'createdAt') THEN
    ALTER TABLE blog_category RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_category' AND column_name = 'updatedAt') THEN
    ALTER TABLE blog_category RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_category' AND column_name = 'parentId') THEN
    ALTER TABLE blog_category RENAME COLUMN "parentId" TO parent_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_category' AND column_name = 'sortOrder') THEN
    ALTER TABLE blog_category RENAME COLUMN "sortOrder" TO sort_order;
  END IF;
END $$;

-- blog_post
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_post' AND column_name = 'createdAt') THEN
    ALTER TABLE blog_post RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_post' AND column_name = 'updatedAt') THEN
    ALTER TABLE blog_post RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_post' AND column_name = 'authorId') THEN
    ALTER TABLE blog_post RENAME COLUMN "authorId" TO author_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_post' AND column_name = 'authorType') THEN
    ALTER TABLE blog_post RENAME COLUMN "authorType" TO author_type;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_post' AND column_name = 'mainImage') THEN
    ALTER TABLE blog_post RENAME COLUMN "mainImage" TO main_image;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_post' AND column_name = 'mainImageSize') THEN
    ALTER TABLE blog_post RENAME COLUMN "mainImageSize" TO main_image_size;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_post' AND column_name = 'metaDescription') THEN
    ALTER TABLE blog_post RENAME COLUMN "metaDescription" TO meta_description;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_post' AND column_name = 'publishDate') THEN
    ALTER TABLE blog_post RENAME COLUMN "publishDate" TO publish_date;
  END IF;
END $$;

-- blog_post_category
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_post_category' AND column_name = 'blogPostId') THEN
    ALTER TABLE blog_post_category RENAME COLUMN "blogPostId" TO blog_post_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_post_category' AND column_name = 'categoryId') THEN
    ALTER TABLE blog_post_category RENAME COLUMN "categoryId" TO category_id;
  END IF;
END $$;

-- blog_view
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_view' AND column_name = 'blogPostId') THEN
    ALTER TABLE blog_view RENAME COLUMN "blogPostId" TO blog_post_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_view' AND column_name = 'userId') THEN
    ALTER TABLE blog_view RENAME COLUMN "userId" TO user_id;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_view' AND column_name = 'ipAddress') THEN
    ALTER TABLE blog_view RENAME COLUMN "ipAddress" TO ip_address;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'blog_view' AND column_name = 'viewedAt') THEN
    ALTER TABLE blog_view RENAME COLUMN "viewedAt" TO viewed_at;
  END IF;
END $$;

-- ============================================================
-- 6. Orphan _int 컬럼 정리 (이전 실패한 enum 변환에서 남은 컬럼)
-- ============================================================

-- status_int → status (career_hub_community_event_participants)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_event_participants' AND column_name = 'status_int')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'career_hub_community_event_participants' AND column_name = 'status') THEN
    ALTER TABLE career_hub_community_event_participants RENAME COLUMN status_int TO status;
  END IF;
END $$;

-- ============================================================
-- 완료 (VIEW 생성은 enum 변환 후 별도 실행)
-- ============================================================

COMMIT;

SELECT 'Column conversion completed successfully!' AS result;

-- ============================================================
-- 7. VIEW 재생성 (트랜잭션 외부에서 실행)
-- enum → integer 변환 후에만 성공함
-- ============================================================

CREATE OR REPLACE VIEW career_hub_event_participant_summary AS
SELECT
  event_id,
  count(*) FILTER (WHERE status = 0)::integer AS registered,
  count(*) FILTER (WHERE status = 1)::integer AS confirmed,
  count(*) FILTER (WHERE status = 3)::integer AS attended,
  count(*) FILTER (WHERE status = 2)::integer AS cancelled,
  count(*) FILTER (WHERE status = 4)::integer AS no_show,
  count(*)::integer AS total
FROM career_hub_community_event_participants
GROUP BY event_id;
