# frozen_string_literal: true

require 'rails_helper'

# CrudActions concern에 대한 통합 테스트
# 임시 모델, 시리얼라이저, 컨트롤러를 생성하여 concern의 동작을 검증합니다.
RSpec.describe 'CrudActions', type: :request do
  # ==================== 테스트용 모델/시리얼라이저/컨트롤러 설정 ====================
  before(:all) do
    ActiveRecord::Schema.define do
      create_table :crud_test_items, force: true do |t|
        t.string :name, null: false
        t.string :description
        t.integer :status, default: 0
        t.string :external_id
        t.timestamps
      end
    end

    # 테스트 모델 정의
    Object.const_set(:CrudTestItem, Class.new(ApplicationRecord) {
      self.table_name = 'crud_test_items'
      enum :status, { draft: 0, published: 1, archived: 2 }, prefix: :status
      validates :name, presence: true
      validates :external_id, uniqueness: true, allow_nil: true

      # Ransack 허용 (테스트용)
      def self.ransackable_attributes(_auth_object = nil)
        %w[name status description created_at updated_at external_id]
      end
    })

    # 테스트 시리얼라이저 정의
    Object.const_set(:CrudTestItemSerializer, Class.new(ApplicationSerializer) {
      set_type :crud_test_item
      attributes :name, :description, :status, :external_id, :created_at, :updated_at
    })

    # 테스트 컨트롤러 정의
    Object.const_set(:CrudTestItemsController, Class.new(ApplicationController) {
      include CrudActions

      rescue_from CrudActions::NotFound do |e|
        render jsonapi_errors: [{ status: '404', title: 'Not Found', detail: e.message }], status: :not_found
      end

      def filter_attributes
        %w[name status created_at]
      end

      def model_params_options
        { only: %i[name description status external_id] }
      end

      def upsert_find_params
        # Extract external_id from the deserialized params
        external_id = jsonapi_deserialize(params, only: [:external_id])["external_id"]
        { external_id: external_id }
      end
    })

    # 테스트 라우트 추가
    Rails.application.routes.draw do
      resources :crud_test_items, only: [:index, :show, :new, :create, :update, :destroy] do
        collection do
          put :upsert
        end
      end

      # 기존 라우트 유지
      mount Rswag::Ui::Engine => "/api-docs"
      mount Rswag::Api::Engine => "/api-docs"
      get "/health/live", to: proc { [200, {}, ["OK"]] }
      get "/health/ready", to: proc { [200, {}, ["OK"]] }
      namespace :api do
        namespace :v1 do
        end
      end
    end
  end

  after(:all) do
    # 테이블 삭제
    ActiveRecord::Schema.define do
      drop_table :crud_test_items, if_exists: true
    end

    # 상수 제거
    Object.send(:remove_const, :CrudTestItemsController) if defined?(CrudTestItemsController)
    Object.send(:remove_const, :CrudTestItemSerializer) if defined?(CrudTestItemSerializer)
    Object.send(:remove_const, :CrudTestItem) if defined?(CrudTestItem)

    # 라우트 재로드
    Rails.application.reload_routes!
  end

  # ==================== 공통 설정 ====================
  let(:jsonapi_headers) do
    { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' }
  end

  let!(:item1) { CrudTestItem.create!(name: 'Item 1', description: 'First item', status: :draft) }
  let!(:item2) { CrudTestItem.create!(name: 'Item 2', description: 'Second item', status: :published) }
  let!(:item3) { CrudTestItem.create!(name: 'Item 3', description: 'Third item', status: :archived) }

  def json_response
    JSON.parse(response.body)
  end

  def jsonapi_payload(attributes, type: 'crud_test_items', id: nil)
    data = { type: type, attributes: attributes }
    data[:id] = id.to_s if id
    { data: data }
  end

  # ==================== GET /crud_test_items (index) ====================
  describe 'GET /crud_test_items' do
    it 'returns a list of records in JSON:API format' do
      get '/crud_test_items', headers: jsonapi_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].size).to eq(3)
    end

    it 'returns correct JSON:API structure' do
      get '/crud_test_items', headers: jsonapi_headers

      first = json_response['data'].first
      expect(first).to have_key('id')
      expect(first).to have_key('type')
      expect(first).to have_key('attributes')
      expect(first['type']).to eq('crud_test_item')
    end

    it 'includes meta with total-count' do
      get '/crud_test_items', headers: jsonapi_headers

      expect(json_response['meta']).to include('total-count')
      expect(json_response['meta']['total-count']).to eq(3)
    end

    context 'with pagination' do
      before do
        7.times { |i| CrudTestItem.create!(name: "Paginated #{i}") }
      end

      it 'paginates results' do
        get '/crud_test_items', params: { page: { number: 1, size: 5 } }, headers: jsonapi_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].size).to eq(5)
      end

      it 'returns second page' do
        get '/crud_test_items', params: { page: { number: 2, size: 5 } }, headers: jsonapi_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].size).to be >= 1
      end
    end

    context 'with Ransack filters' do
      it 'filters by exact match (_eq)' do
        get '/crud_test_items', params: { filter: { name_eq: 'Item 1' } }, headers: jsonapi_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].size).to eq(1)
        expect(json_response['data'].first['attributes']['name']).to eq('Item 1')
      end

      it 'filters by partial match (_cont)' do
        get '/crud_test_items', params: { filter: { name_cont: 'Item' } }, headers: jsonapi_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].size).to eq(3)
      end
    end

    context 'with enum filters' do
      it 'converts string enum value to integer for _eq filter' do
        get '/crud_test_items', params: { filter: { status_eq: 'published' } }, headers: jsonapi_headers

        expect(response).to have_http_status(:ok)
        names = json_response['data'].map { |d| d['attributes']['name'] }
        expect(names).to include('Item 2')
        expect(names).not_to include('Item 1')
      end
    end
  end

  # ==================== GET /crud_test_items/:id (show) ====================
  describe 'GET /crud_test_items/:id' do
    it 'returns a single record' do
      get "/crud_test_items/#{item1.id}", headers: jsonapi_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['id']).to eq(item1.id.to_s)
      expect(json_response['data']['attributes']['name']).to eq('Item 1')
    end

    it 'returns 404 when record not found' do
      get '/crud_test_items/99999', headers: jsonapi_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  # ==================== POST /crud_test_items (create) ====================
  describe 'POST /crud_test_items' do
    context 'with valid params' do
      it 'creates a new record' do
        valid_payload = jsonapi_payload({ name: 'New Item', description: 'A new item' })
        expect {
          post '/crud_test_items', params: valid_payload.to_json, headers: jsonapi_headers
        }.to change(CrudTestItem, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['attributes']['name']).to eq('New Item')
      end
    end

    context 'with invalid params' do
      it 'returns 422 with validation errors' do
        invalid_payload = jsonapi_payload({ name: '', description: 'Missing name' })
        expect {
          post '/crud_test_items', params: invalid_payload.to_json, headers: jsonapi_headers
        }.not_to change(CrudTestItem, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to be_present
      end
    end
  end

  # ==================== PATCH /crud_test_items/:id (update) ====================
  describe 'PATCH /crud_test_items/:id' do
    context 'with valid params' do
      it 'updates the record' do
        update_payload = jsonapi_payload({ name: 'Updated Item' }, id: item1.id)
        patch "/crud_test_items/#{item1.id}", params: update_payload.to_json, headers: jsonapi_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['attributes']['name']).to eq('Updated Item')
        expect(item1.reload.name).to eq('Updated Item')
      end
    end

    context 'with invalid params' do
      it 'returns 422 with validation errors' do
        invalid_payload = jsonapi_payload({ name: '' }, id: item1.id)
        patch "/crud_test_items/#{item1.id}", params: invalid_payload.to_json, headers: jsonapi_headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(item1.reload.name).to eq('Item 1')
      end
    end

    it 'returns 404 when record not found' do
      payload = jsonapi_payload({ name: 'Ghost' }, id: 99999)
      patch '/crud_test_items/99999', params: payload.to_json, headers: jsonapi_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  # ==================== DELETE /crud_test_items/:id (destroy) ====================
  describe 'DELETE /crud_test_items/:id' do
    it 'deletes the record' do
      expect {
        delete "/crud_test_items/#{item1.id}", headers: jsonapi_headers
      }.to change(CrudTestItem, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'returns 404 when record not found' do
      delete '/crud_test_items/99999', headers: jsonapi_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  # ==================== PUT /crud_test_items/upsert (upsert) ====================
  describe 'PUT /crud_test_items/upsert' do
    context 'when record does not exist (create)' do
      it 'creates a new record with 201 status' do
        upsert_payload = jsonapi_payload({ name: 'Upserted Item', description: 'New via upsert', external_id: 'ext-new-001' })
        expect {
          put '/crud_test_items/upsert', params: upsert_payload.to_json, headers: jsonapi_headers
        }.to change(CrudTestItem, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['data']['attributes']['name']).to eq('Upserted Item')
        expect(json_response['data']['attributes']['external_id']).to eq('ext-new-001')
      end
    end

    context 'when record already exists (update)' do
      let!(:existing) { CrudTestItem.create!(name: 'Old Name', external_id: 'ext-exist-001') }

      it 'updates the existing record with 200 status' do
        upsert_payload = jsonapi_payload({ name: 'Updated Name', description: 'Updated via upsert', external_id: 'ext-exist-001' })
        expect {
          put '/crud_test_items/upsert', params: upsert_payload.to_json, headers: jsonapi_headers
        }.not_to change(CrudTestItem, :count)

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['attributes']['name']).to eq('Updated Name')
        expect(existing.reload.name).to eq('Updated Name')
      end
    end

    context 'with invalid params' do
      it 'returns 422 with validation errors' do
        invalid_payload = jsonapi_payload({ name: '', external_id: 'ext-invalid-001' })
        put '/crud_test_items/upsert', params: invalid_payload.to_json, headers: jsonapi_headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to be_present
      end
    end
  end

  # ==================== JsonApiError ====================
  describe 'JsonApiError' do
    it 'stores title, message, and status' do
      error = CrudActions::JsonApiError.new('TestTitle', 'Test message', 422)
      expect(error.title).to eq('TestTitle')
      expect(error.message).to eq('Test message')
      expect(error.status).to eq(422)
    end

    it 'defaults status to 500' do
      error = CrudActions::JsonApiError.new('Error', 'Something went wrong')
      expect(error.status).to eq('500')
    end

    it 'inherits from StandardError' do
      expect(CrudActions::JsonApiError.superclass).to eq(StandardError)
    end
  end

  # ==================== NotFound ====================
  describe 'NotFound' do
    it 'inherits from JsonApiError' do
      expect(CrudActions::NotFound.superclass).to eq(CrudActions::JsonApiError)
    end
  end

  # ==================== includes_for_active_record ====================
  describe '#includes_for_active_record' do
    # includes_for_active_record는 컨트롤러 인스턴스 메서드이므로
    # 컨트롤러를 통해 간접 테스트
    it 'handles simple include paths via request' do
      # allowed_includes가 빈 배열이므로 include는 무시됨
      get '/crud_test_items', params: { include: 'user' }, headers: jsonapi_headers

      expect(response).to have_http_status(:ok)
    end
  end

  # ==================== 기본값 테스트 ====================
  describe 'default values' do
    it 'filter_attributes can be overridden' do
      # CrudTestItemsController는 filter_attributes를 오버라이드하여 name, status, created_at을 반환
      # 필터가 작동하는지 검증
      get '/crud_test_items', params: { filter: { name_eq: 'Item 1' } }, headers: jsonapi_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(1)
    end
  end
end
