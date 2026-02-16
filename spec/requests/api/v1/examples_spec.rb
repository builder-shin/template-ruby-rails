# frozen_string_literal: true

#
# ============================================================
# [참고용 예시 파일] - REFERENCE ONLY
# 이 파일은 프로젝트의 리퀘스트 스펙 작성 패턴을 보여주기 위한 예시입니다.
# 실제 사용 시 이 파일을 삭제하고 새로운 스펙을 생성하세요.
# ============================================================
#

require 'rails_helper'

RSpec.describe 'Api::V1::Examples', type: :request do
  # ==================== JSON:API 헤더 설정 ====================
  let(:jsonapi_headers) do
    {
      'Content-Type' => 'application/vnd.api+json',
      'Accept' => 'application/vnd.api+json'
    }
  end

  # ==================== Factory 및 테스트 데이터 ====================
  # AuthUser는 ActiveModel이므로 attrs hash로 mock 설정
  let(:user_attrs) { { id: SecureRandom.uuid, email: 'test@example.com', name: 'Test User' } }
  let(:other_user_attrs) { { id: SecureRandom.uuid, email: 'other@example.com', name: 'Other User' } }

  # 도메인 모델 factory (실제 프로젝트에서는 FactoryBot factory 정의 필요)
  let(:category) { create(:category) }

  let!(:example1) { create(:example, user_id: user_attrs[:id], name: 'Example 1', status: 'published') }
  let!(:example2) { create(:example, user_id: user_attrs[:id], name: 'Example 2', status: 'draft') }
  let!(:other_example) { create(:example, user_id: other_user_attrs[:id], name: 'Other Example') }

  # ==================== GET /api/v1/examples (index) ====================
  describe 'GET /api/v1/examples' do
    context 'when authenticated' do
      before do
        mock_authenticated_user(user_attrs)
      end

      it 'returns examples list' do
        get '/api/v1/examples', headers: jsonapi_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['data']).to be_an(Array)
        expect(json_response['data'].size).to be >= 1
      end

      it 'returns correct JSON:API structure' do
        get '/api/v1/examples', headers: jsonapi_headers

        expect(json_response).to have_key('data')
        expect(json_response).to have_key('meta')
        expect(json_response['data'].first).to have_key('id')
        expect(json_response['data'].first).to have_key('type')
        expect(json_response['data'].first).to have_key('attributes')
      end

      # ==================== Pagination 테스트 ====================
      context 'with pagination params' do
        before do
          create_list(:example, 15, user_id: user_attrs[:id])
        end

        it 'paginates results' do
          get '/api/v1/examples',
              params: { page: { number: 1, size: 10 } },
              headers: jsonapi_headers

          expect(json_response['data'].size).to eq(10)
          expect(json_response['meta']).to have_key('page')
          expect(json_response['meta']['page']['total_pages']).to be >= 2
        end

        it 'returns second page' do
          get '/api/v1/examples',
              params: { page: { number: 2, size: 10 } },
              headers: jsonapi_headers

          expect(response).to have_http_status(:ok)
          expect(json_response['data'].size).to be >= 1
        end
      end

      # ==================== Filtering 테스트 (Ransack) ====================
      context 'with filter params' do
        it 'filters by exact match (eq)' do
          get '/api/v1/examples',
              params: { filter: { status_eq: 'published' } },
              headers: jsonapi_headers

          expect(response).to have_http_status(:ok)
          expect(json_response['data'].all? { |e| e['attributes']['status'] == 'published' }).to be true
        end

        it 'filters by partial match (cont)' do
          get '/api/v1/examples',
              params: { filter: { name_cont: 'Example 1' } },
              headers: jsonapi_headers

          expect(response).to have_http_status(:ok)
          expect(json_response['data'].size).to eq(1)
          expect(json_response['data'].first['attributes']['name']).to eq('Example 1')
        end

        it 'filters by date range (gt/lt)' do
          get '/api/v1/examples',
              params: { filter: { created_at_gt: 1.day.ago.iso8601 } },
              headers: jsonapi_headers

          expect(response).to have_http_status(:ok)
        end
      end

      # ==================== Include 테스트 ====================
      context 'with include params' do
        it 'includes related resources' do
          get '/api/v1/examples',
              params: { include: 'user,category' },
              headers: jsonapi_headers

          expect(response).to have_http_status(:ok)
          expect(json_response).to have_key('included')
          expect(json_response['included']).to be_an(Array)
        end
      end

      # ==================== Sorting 테스트 ====================
      context 'with sort params' do
        it 'sorts by name ascending' do
          get '/api/v1/examples',
              params: { sort: 'name' },
              headers: jsonapi_headers

          names = json_response['data'].map { |e| e['attributes']['name'] }
          expect(names).to eq(names.sort)
        end

        it 'sorts by created_at descending' do
          get '/api/v1/examples',
              params: { sort: '-created_at' },
              headers: jsonapi_headers

          expect(response).to have_http_status(:ok)
        end
      end
    end

    # ==================== 인증 실패 테스트 ====================
    context 'when unauthenticated' do
      before do
        mock_unauthenticated
      end

      it 'returns 401 unauthorized' do
        get '/api/v1/examples', headers: jsonapi_headers

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'].first['status']).to eq('401')
      end
    end

    # ==================== 인증 서비스 장애 테스트 ====================
    context 'when auth service is unavailable' do
      before do
        mock_auth_service_unavailable
      end

      it 'returns 503 service unavailable' do
        get '/api/v1/examples', headers: jsonapi_headers

        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end

  # ==================== GET /api/v1/examples/:id (show) ====================
  describe 'GET /api/v1/examples/:id' do
    context 'when authenticated' do
      before do
        mock_authenticated_user(user_attrs)
      end

      it 'returns the example' do
        get "/api/v1/examples/#{example1.id}", headers: jsonapi_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['id']).to eq(example1.id.to_s)
        expect(json_response['data']['attributes']['name']).to eq(example1.name)
      end

      it 'includes relationships' do
        get "/api/v1/examples/#{example1.id}",
            params: { include: 'user' },
            headers: jsonapi_headers

        expect(response).to have_http_status(:ok)
        expect(json_response).to have_key('included')
      end

      context 'when example does not exist' do
        it 'returns 404 not found' do
          get '/api/v1/examples/99999', headers: jsonapi_headers

          expect(response).to have_http_status(:not_found)
          expect(json_response['errors']).to be_present
        end
      end
    end

    context 'when unauthenticated' do
      before do
        mock_unauthenticated
      end

      it 'returns 401 unauthorized' do
        get "/api/v1/examples/#{example1.id}", headers: jsonapi_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ==================== POST /api/v1/examples (create) ====================
  describe 'POST /api/v1/examples' do
    let(:valid_payload) do
      {
        data: {
          type: 'examples',
          attributes: {
            name: 'New Example',
            description: 'This is a new example',
            status: 'draft'
          },
          relationships: {
            category: {
              data: { type: 'categories', id: category.id.to_s }
            }
          }
        }
      }
    end

    context 'when authenticated' do
      before do
        mock_authenticated_user(user_attrs)
      end

      it 'creates a new example' do
        expect {
          post '/api/v1/examples',
               params: valid_payload.to_json,
               headers: jsonapi_headers
        }.to change(Example, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['data']['attributes']['name']).to eq('New Example')
      end

      it 'associates example with current user' do
        post '/api/v1/examples',
             params: valid_payload.to_json,
             headers: jsonapi_headers

        created_example = Example.find(json_response['data']['id'])
        expect(created_example.user_id).to eq(user_attrs[:id])
      end

      context 'with invalid params' do
        let(:invalid_payload) do
          {
            data: {
              type: 'examples',
              attributes: {
                name: '', # invalid: empty name
                description: 'Test'
              }
            }
          }
        end

        it 'returns 422 unprocessable entity' do
          post '/api/v1/examples',
               params: invalid_payload.to_json,
               headers: jsonapi_headers

          expect(response).to have_http_status(:unprocessable_entity)
          expect(json_response['errors']).to be_present
          expect(json_response['errors'].first['source']['pointer']).to include('/data/attributes/name')
        end
      end

      context 'with missing required attributes' do
        let(:incomplete_payload) do
          {
            data: {
              type: 'examples',
              attributes: {}
            }
          }
        end

        it 'returns validation errors' do
          post '/api/v1/examples',
               params: incomplete_payload.to_json,
               headers: jsonapi_headers

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context 'when unauthenticated' do
      before do
        mock_unauthenticated
      end

      it 'returns 401 unauthorized' do
        post '/api/v1/examples',
             params: valid_payload.to_json,
             headers: jsonapi_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end

    # ==================== Authorization 테스트 (user type) ====================
    context 'when authenticated as enterprise user' do
      before do
        mock_enterprise_user
      end

      it 'allows creation for enterprise users' do
        post '/api/v1/examples',
             params: valid_payload.to_json,
             headers: jsonapi_headers

        expect(response).to have_http_status(:created)
      end
    end
  end

  # ==================== PATCH /api/v1/examples/:id (update) ====================
  describe 'PATCH /api/v1/examples/:id' do
    let(:update_payload) do
      {
        data: {
          type: 'examples',
          id: example2.id.to_s,
          attributes: {
            name: 'Updated Example',
            status: 'published'
          }
        }
      }
    end

    context 'when authenticated as owner' do
      before do
        mock_authenticated_user(user_attrs)
      end

      it 'updates the example' do
        patch "/api/v1/examples/#{example2.id}",
              params: update_payload.to_json,
              headers: jsonapi_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['attributes']['name']).to eq('Updated Example')
        expect(example2.reload.name).to eq('Updated Example')
      end

      it 'returns updated resource' do
        patch "/api/v1/examples/#{example2.id}",
              params: update_payload.to_json,
              headers: jsonapi_headers

        expect(json_response['data']['id']).to eq(example2.id.to_s)
        expect(json_response['data']['attributes']['status']).to eq('published')
      end

      context 'with invalid update' do
        let(:invalid_update) do
          {
            data: {
              type: 'examples',
              id: example2.id.to_s,
              attributes: { name: '' }
            }
          }
        end

        it 'returns 422 with errors' do
          patch "/api/v1/examples/#{example2.id}",
                params: invalid_update.to_json,
                headers: jsonapi_headers

          expect(response).to have_http_status(:unprocessable_entity)
          expect(json_response['errors']).to be_present
        end
      end
    end

    context 'when authenticated as different user' do
      before do
        mock_authenticated_user(other_user_attrs)
      end

      it 'returns 403 forbidden' do
        patch "/api/v1/examples/#{example2.id}",
              params: update_payload.to_json,
              headers: jsonapi_headers

        expect(response).to have_http_status(:forbidden)
        expect(json_response['errors'].first['status']).to eq('403')
      end
    end

    context 'when unauthenticated' do
      before do
        mock_unauthenticated
      end

      it 'returns 401 unauthorized' do
        patch "/api/v1/examples/#{example2.id}",
              params: update_payload.to_json,
              headers: jsonapi_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ==================== PUT /api/v1/examples/upsert (upsert) ====================
  describe 'PUT /api/v1/examples/upsert' do
    let(:upsert_payload) do
      {
        data: {
          type: 'examples',
          attributes: {
            external_id: 'ext-123',
            name: 'Upserted Example',
            description: 'Created or updated via upsert'
          }
        }
      }
    end

    context 'when authenticated' do
      before do
        mock_authenticated_user(user_attrs)
      end

      context 'when record does not exist' do
        it 'creates a new record' do
          expect {
            put '/api/v1/examples/upsert',
                params: upsert_payload.to_json,
                headers: jsonapi_headers
          }.to change(Example, :count).by(1)

          expect(response).to have_http_status(:created)
          expect(json_response['data']['attributes']['name']).to eq('Upserted Example')
        end
      end

      context 'when record already exists' do
        let!(:existing) { create(:example, external_id: 'ext-123', name: 'Old Name') }

        it 'updates the existing record' do
          expect {
            put '/api/v1/examples/upsert',
                params: upsert_payload.to_json,
                headers: jsonapi_headers
          }.not_to change(Example, :count)

          expect(response).to have_http_status(:ok)
          expect(json_response['data']['attributes']['name']).to eq('Upserted Example')
          expect(existing.reload.name).to eq('Upserted Example')
        end
      end

      context 'with invalid params' do
        let(:invalid_upsert) do
          {
            data: {
              type: 'examples',
              attributes: {
                external_id: 'ext-123',
                name: '' # invalid
              }
            }
          }
        end

        it 'returns 422 unprocessable entity' do
          put '/api/v1/examples/upsert',
              params: invalid_upsert.to_json,
              headers: jsonapi_headers

          expect(response).to have_http_status(:unprocessable_entity)
          expect(json_response['errors']).to be_present
        end
      end
    end

    context 'when unauthenticated' do
      before { mock_unauthenticated }

      it 'returns 401 unauthorized' do
        put '/api/v1/examples/upsert',
            params: upsert_payload.to_json,
            headers: jsonapi_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ==================== DELETE /api/v1/examples/:id (destroy) ====================
  describe 'DELETE /api/v1/examples/:id' do
    context 'when authenticated as owner' do
      before do
        mock_authenticated_user(user_attrs)
      end

      it 'deletes the example' do
        expect {
          delete "/api/v1/examples/#{example2.id}", headers: jsonapi_headers
        }.to change(Example, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end

      it 'returns no content' do
        delete "/api/v1/examples/#{example2.id}", headers: jsonapi_headers

        expect(response.body).to be_empty
      end

      context 'when example does not exist' do
        it 'returns 404 not found' do
          delete '/api/v1/examples/99999', headers: jsonapi_headers

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when authenticated as different user' do
      before do
        mock_authenticated_user(other_user_attrs)
      end

      it 'returns 403 forbidden' do
        delete "/api/v1/examples/#{example2.id}", headers: jsonapi_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      before do
        mock_unauthenticated
      end

      it 'returns 401 unauthorized' do
        delete "/api/v1/examples/#{example2.id}", headers: jsonapi_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ==================== 헬퍼 메서드 ====================
  # 이 메서드를 spec/support/request_helper.rb로 분리하는 것을 권장합니다
  def json_response
    JSON.parse(response.body)
  end
end
