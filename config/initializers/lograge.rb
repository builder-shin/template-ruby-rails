Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new

  config.lograge.custom_options = lambda do |event|
    {
      time: Time.current.iso8601,
      request_id: event.payload[:request_id],
      remote_ip: event.payload[:remote_ip],
      user_id: event.payload[:user_id],
      params: event.payload[:params]&.except("controller", "action", "format")
    }.compact
  end

  config.lograge.custom_payload do |controller|
    {
      remote_ip: controller.request.remote_ip,
      user_id: Current.user&.id,
      # Task 4부터 Current.user가 AuthUser(workspace_id 있음)뿐 아니라 User(없음)도
      # 될 수 있다. &.workspace_id는 nil 수신자만 걸러내지 nil이 아닌 User에 없는
      # 메서드는 그대로 NoMethodError로 죽는다 — Bearer 가드를 통과한 요청마다 응답
      # 자체가 500으로 깨진다(lograge가 process_action.action_controller의 ensure에서
      # 구독하므로). try는 응답하지 않는 메서드에 nil을 돌려줘 두 타입 모두 안전하다.
      workspace_id: Current.user.try(:workspace_id),
      request_id: controller.request.request_id
    }
  end
end
