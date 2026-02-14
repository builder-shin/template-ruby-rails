<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-14 | Updated: 2026-02-14 -->

# models

## Purpose
ActiveRecord 모델. 채용 플랫폼의 도메인 엔티티를 정의한다. 모든 모델은 `ApplicationRecord`를 상속하며, Ransack 필터링이 기본 활성화되어 있다.

## Key Files

| File | Description |
|------|-------------|
| `application_record.rb` | 베이스 모델 — Ransack 전체 허용 설정 |
| `current.rb` | `Current` thread-local 저장소 (현재 사용자) |
| `auth_user.rb` | 인증된 사용자 값 객체 (외부 Auth 서비스 응답) |
| `profile.rb` | 프로필 (구직자 프로필, 핵심 엔티티) |
| `job_post.rb` | 채용 공고 |
| `job.rb` | 직무 |
| `job_category.rb` | 직군 카테고리 |
| `job_application.rb` | 채용 지원서 |
| `country.rb` | 국가 참조 데이터 |
| `blog_post.rb` | 블로그 게시글 |
| `recruitment_request.rb` | 채용 의뢰 |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `auth/` | 외부 Auth DB 읽기 전용 모델 (FDW) (see `auth/AGENTS.md`) |
| `concerns/` | 모델 공통 concern |

## For AI Agents

### Working In This Directory
- `ApplicationRecord` 상속 필수
- UUID PK 사용하는 테이블이 대부분 (일부 bigint PK 존재: blog_*, recruitment_requests)
- Association 이름 = 테이블명 기준 (Rails 컨벤션)
- `class_name`은 자기 참조, 역할 alias 등 추론 불가 시에만 사용
- FK 컬럼명이 `#{관계명}_id`와 다르면 `foreign_key:` 명시

### Domain Groups
- **프로필**: `Profile`, `ProfileEducation`, `ProfileExperience`, `ProfileFreelanceExperience`, `ProfileHighlight`, `ProfileJob`, `ProfileLanguage`, `ProfileLink`, `ProfileProject`, `ProfileAttachment`, `FeaturedProfile`
- **채용**: `JobPost`, `JobPostCategory`, `JobPostJob`, `JobPostLanguage`, `JobPostStatusLog`, `JobApplication`, `Job`, `JobCategory`
- **블로그**: `BlogPost`, `BlogPostCategory`, `BlogCategory`, `BlogView`, `BlogAuthorPermission`
- **커리어허브**: `CareerHubCategory`, `CareerHubCommunity`, `CareerHubCommunityEvent`, `CareerHubCommunityEventParticipant`, `CareerHubCommunityFeed`, `CareerHubCommunityFeedLike`, `CareerHubCommunityLeader`, `CareerHubCommunityMember`, `CareerHubEventReview`
- **참조**: `Country`, `HighlightReference`, `PracticalStrengthReference`, `ApplicationContextReference`
- **기타**: `EmailTemplate`, `EventNotificationSchedule`, `RecommendationNotificationHistory`, `RecruitmentRequest`

<!-- MANUAL: -->
