-- ============================================================
-- PostgreSQL Enum → Integer 변환 스크립트
-- 작성일: 2026-02-04
-- 대상: 모든 PostgreSQL enum 타입
-- ============================================================

BEGIN;

-- ============================================================
-- Helper function: enum을 integer로 변환
-- ============================================================

CREATE OR REPLACE FUNCTION convert_enum_to_int(
  p_table TEXT,
  p_column TEXT,
  p_mapping JSONB
) RETURNS VOID AS $$
DECLARE
  v_temp_column TEXT;
  v_case_stmt TEXT;
  v_key TEXT;
  v_value INT;
BEGIN
  v_temp_column := p_column || '_int';

  -- 이전 실행에서 남은 _int 컬럼이 있으면 정리 (원본 컬럼 없이 _int만 남은 경우)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = p_table AND column_name = v_temp_column
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = p_table AND column_name = p_column
  ) THEN
    EXECUTE format('ALTER TABLE %I RENAME COLUMN %I TO %I', p_table, v_temp_column, p_column);
    RAISE NOTICE 'Renamed orphan %.%_int to %', p_table, p_column, p_column;
    RETURN;
  END IF;

  -- 컬럼이 존재하는지 확인
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = p_table AND column_name = p_column
  ) THEN
    RAISE NOTICE 'Skipping %.% - column does not exist', p_table, p_column;
    RETURN;
  END IF;

  -- 이미 integer인지 확인
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = p_table AND column_name = p_column AND data_type = 'integer'
  ) THEN
    RAISE NOTICE 'Skipping %.% - already integer', p_table, p_column;
    RETURN;
  END IF;

  -- CASE 문 생성
  v_case_stmt := '';
  FOR v_key, v_value IN SELECT * FROM jsonb_each_text(p_mapping)
  LOOP
    v_case_stmt := v_case_stmt || format(' WHEN %L THEN %s', v_key, v_value);
  END LOOP;

  -- 임시 컬럼 추가
  EXECUTE format('ALTER TABLE %I ADD COLUMN %I integer', p_table, v_temp_column);

  -- 데이터 변환
  EXECUTE format(
    'UPDATE %I SET %I = CASE %I::text %s ELSE NULL END WHERE %I IS NOT NULL',
    p_table, v_temp_column, p_column, v_case_stmt, p_column
  );

  -- 기존 컬럼 삭제
  EXECUTE format('ALTER TABLE %I DROP COLUMN %I', p_table, p_column);

  -- 임시 컬럼 이름 변경
  EXECUTE format('ALTER TABLE %I RENAME COLUMN %I TO %I', p_table, v_temp_column, p_column);

  RAISE NOTICE 'Converted %.% to integer', p_table, p_column;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 1. career_hub 관련 enum 변환
-- ============================================================

-- career_hub_communities.status
SELECT convert_enum_to_int('career_hub_communities', 'status',
  '{"pending": 0, "active": 1, "inactive": 2, "suspended": 3}'::jsonb);

-- career_hub_communities.join_policy
SELECT convert_enum_to_int('career_hub_communities', 'join_policy',
  '{"open": 0, "approval": 1}'::jsonb);

-- career_hub_community_event_participants.status
SELECT convert_enum_to_int('career_hub_community_event_participants', 'status',
  '{"registered": 0, "confirmed": 1, "cancelled": 2, "attended": 3, "no_show": 4}'::jsonb);

-- career_hub_community_events.status
SELECT convert_enum_to_int('career_hub_community_events', 'status',
  '{"draft": 0, "pending": 1, "scheduled": 2, "active": 3, "completed": 4, "closed": 5, "cancelled": 6, "suspended": 7}'::jsonb);

-- career_hub_community_feeds.status
SELECT convert_enum_to_int('career_hub_community_feeds', 'status',
  '{"active": 0, "deleted": 1, "hidden": 2}'::jsonb);

-- career_hub_community_leaders.status
SELECT convert_enum_to_int('career_hub_community_leaders', 'status',
  '{"pending": 0, "approved": 1, "rejected": 2, "suspended": 3}'::jsonb);

-- career_hub_community_members.status
SELECT convert_enum_to_int('career_hub_community_members', 'status',
  '{"pending": 0, "active": 1, "inactive": 2, "banned": 3}'::jsonb);

-- ============================================================
-- 2. event_notification_schedules enum 변환
-- ============================================================

SELECT convert_enum_to_int('event_notification_schedules', 'target_type',
  '{"community_event": 0, "job_post": 1}'::jsonb);

SELECT convert_enum_to_int('event_notification_schedules', 'trigger_type',
  '{"days_before": 0, "hours_before": 1}'::jsonb);

-- ============================================================
-- 3. highlight_references enum 변환
-- ============================================================

SELECT convert_enum_to_int('highlight_references', 'highlight_type',
  '{"BEFORE": 0, "ACTION": 1, "AFTER": 2}'::jsonb);

-- ============================================================
-- 4. job 관련 enum 변환
-- ============================================================

-- job_applications.status
SELECT convert_enum_to_int('job_applications', 'status',
  '{"SUBMITTED": 0, "UNDER_REVIEW": 1, "DOCUMENT_PASSED": 2, "ACCEPTED": 3, "FINAL_PASSED": 4, "REJECTED": 5, "CANCELED": 6}'::jsonb);

-- job_post_languages.proficiency
SELECT convert_enum_to_int('job_post_languages', 'proficiency',
  '{"BASIC": 0, "CONVERSATIONAL": 1, "BUSINESS": 2, "FLUENT": 3, "NATIVE": 4}'::jsonb);

-- job_post_status_logs.changed_by_type
SELECT convert_enum_to_int('job_post_status_logs', 'changed_by_type',
  '{"ADMIN": 0, "COMPANY": 1, "SYSTEM": 2}'::jsonb);

-- job_post_status_logs.from_status
SELECT convert_enum_to_int('job_post_status_logs', 'from_status',
  '{"DRAFT": 0, "COMPLETED": 1, "PENDING_REVIEW": 2, "PENDING_PUBLISH": 3, "RECRUITING": 4, "CLOSED": 5, "REJECTED": 6, "COMPANY_STOPPED": 7, "ADMIN_STOPPED": 8}'::jsonb);

-- job_post_status_logs.to_status
SELECT convert_enum_to_int('job_post_status_logs', 'to_status',
  '{"DRAFT": 0, "COMPLETED": 1, "PENDING_REVIEW": 2, "PENDING_PUBLISH": 3, "RECRUITING": 4, "CLOSED": 5, "REJECTED": 6, "COMPANY_STOPPED": 7, "ADMIN_STOPPED": 8}'::jsonb);

-- job_posts.status
SELECT convert_enum_to_int('job_posts', 'status',
  '{"DRAFT": 0, "COMPLETED": 1, "PENDING_REVIEW": 2, "PENDING_PUBLISH": 3, "RECRUITING": 4, "CLOSED": 5, "REJECTED": 6, "COMPANY_STOPPED": 7, "ADMIN_STOPPED": 8}'::jsonb);

-- job_posts.deadline_type
SELECT convert_enum_to_int('job_posts', 'deadline_type',
  '{"UNTIL_FILLED": 0, "FIXED_DATE": 1}'::jsonb);

-- job_posts.employment_type
SELECT convert_enum_to_int('job_posts', 'employment_type',
  '{"FREELANCER": 0, "CONTRACT": 1, "FULL_TIME": 2}'::jsonb);

-- job_posts.experience_level
SELECT convert_enum_to_int('job_posts', 'experience_level',
  '{"UNDER_5_YEARS": 0, "FROM_5_TO_10_YEARS": 1, "FROM_10_TO_20_YEARS": 2, "OVER_20_YEARS": 3}'::jsonb);

-- job_posts.publication_type
SELECT convert_enum_to_int('job_posts', 'publication_type',
  '{"IMMEDIATE": 0, "SCHEDULED": 1}'::jsonb);

-- ============================================================
-- 5. profile 관련 enum 변환
-- ============================================================

-- profile_educations.education_level
SELECT convert_enum_to_int('profile_educations', 'education_level',
  '{"HIGH_SCHOOL": 0, "COLLEGE": 1, "UNIVERSITY": 2, "MASTERS": 3, "DOCTORATE": 4, "INTEGRATED_MASTERS_DOCTORATE": 5}'::jsonb);

-- profile_educations.status
SELECT convert_enum_to_int('profile_educations', 'status',
  '{"ENROLLED": 0, "ON_LEAVE": 1, "EXPECTED_GRADUATION": 2, "GRADUATED": 3, "COMPLETED": 4, "DROPPED_OUT": 5}'::jsonb);

-- profile_experiences.work_type
SELECT convert_enum_to_int('profile_experiences', 'work_type',
  '{"ON_SITE": 0, "HYBRID": 1, "REMOTE": 2}'::jsonb);

-- profile_freelance_experiences.work_type
SELECT convert_enum_to_int('profile_freelance_experiences', 'work_type',
  '{"ON_SITE": 0, "HYBRID": 1, "REMOTE": 2}'::jsonb);

-- profile_languages.proficiency
SELECT convert_enum_to_int('profile_languages', 'proficiency',
  '{"BASIC": 0, "CONVERSATIONAL": 1, "BUSINESS": 2, "FLUENT": 3, "NATIVE": 4}'::jsonb);

-- profiles.job_seeking_status
SELECT convert_enum_to_int('profiles', 'job_seeking_status',
  '{"ACTIVELY_SEEKING": 0, "OPEN_TO_OFFERS": 1, "NOT_SEEKING": 2}'::jsonb);

-- profiles.start_work
SELECT convert_enum_to_int('profiles', 'start_work',
  '{"WITHIN_ONE_WEEK": 0, "WITHIN_ONE_MONTH": 1, "ONE_MONTH_AFTER_OFFER": 2, "NEGOTIABLE": 3}'::jsonb);

-- ============================================================
-- 6. Enum 타입 삭제
-- ============================================================

-- CASCADE 없이 삭제 (변환이 완료된 경우에만 삭제됨)
-- 컬럼이 아직 이 타입을 사용 중이면 오류 발생하므로 안전
DROP TYPE IF EXISTS career_hub_communities_joinpolicy_enum;
DROP TYPE IF EXISTS career_hub_communities_status_enum;
DROP TYPE IF EXISTS career_hub_community_event_participants_status_enum;
DROP TYPE IF EXISTS career_hub_community_events_status_enum;
DROP TYPE IF EXISTS career_hub_community_feeds_status_enum;
DROP TYPE IF EXISTS career_hub_community_members_status_enum;
DROP TYPE IF EXISTS career_hub_leader_status_enum;
DROP TYPE IF EXISTS event_notification_target_type_enum;
DROP TYPE IF EXISTS event_notification_trigger_type_enum;
DROP TYPE IF EXISTS highlight_references_highlighttype_enum;
DROP TYPE IF EXISTS job_applications_status_enum;
DROP TYPE IF EXISTS job_post_status_logs_changedbytype_enum;
DROP TYPE IF EXISTS job_posts_deadlinetype_enum;
DROP TYPE IF EXISTS job_posts_employmenttype_enum;
DROP TYPE IF EXISTS job_posts_experiencelevel_enum;
DROP TYPE IF EXISTS job_posts_publicationtype_enum;
DROP TYPE IF EXISTS job_posts_status_enum;
DROP TYPE IF EXISTS language_proficiency_enum;
DROP TYPE IF EXISTS profile_educations_educationlevel_enum;
DROP TYPE IF EXISTS profile_educations_status_enum;
DROP TYPE IF EXISTS profile_experiences_worktype_enum;
DROP TYPE IF EXISTS profile_freelance_experiences_worktype_enum;
DROP TYPE IF EXISTS profiles_jobseekingstatus_enum;
DROP TYPE IF EXISTS profiles_startwork_enum;

-- ============================================================
-- 7. Helper function 삭제
-- ============================================================

DROP FUNCTION IF EXISTS convert_enum_to_int(TEXT, TEXT, JSONB);

-- ============================================================
-- 완료
-- ============================================================

COMMIT;

SELECT 'Enum to integer conversion completed successfully!' AS result;
