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
      # 이 custom_payload 블록은 지금 이 앱에서 실제로 돌지 않는다 — 확인 완료.
      # lograge#setup_custom_payload는 config.lograge.base_controller_class가
      # 비어 있으면(여기서 그렇다) ActionController::Base에만 append_info_to_payload를
      # 얹는다(lograge.rb:167-169, "base_classes << ActionController::Base if
      # base_classes.empty?"). 이 저장소의 모든 컨트롤러는 ActionController::API를
      # 물려받고 ActionController::Base는 물려받지 않는다
      # (ApplicationController.instance_method(:append_info_to_payload).owner는
      # ActiveRecord::Railties::ControllerRuntime이지 lograge가 아니다) —
      # 그래서 이 블록은 한 번도 실행된 적이 없고, log/test.log의 실제 요청 줄에도
      # user_id·workspace_id·remote_ip·request_id가 전혀 없다. &.workspace_id를
      # try(:workspace_id)로 되돌려도(즉 이 자리를 원래대로 무너뜨려도) 어떤 테스트도
      # 잡지 못한다 — 죽은 코드를 고정할 테스트는 없다.
      #
      # 그래도 try를 쓰는 이유는 방어적 정합성이다: Current.user가 이제
      # AuthUser(workspace_id 있음)뿐 아니라 User(없음)도 될 수 있는데, &.는 nil
      # 수신자만 걸러내지 nil이 아닌 User에 없는 메서드 호출까지 막아주지는 않는다.
      # 누군가 나중에 base_controller_class를 "ApplicationController"로 설정해
      # (이 템플릿이 지금까지 한 번도 user_id/remote_ip/request_id를 프로덕션 로그에
      # 남긴 적이 없다는 별도의 기존 관측성 결함을 고치면) 이 블록이 실제로 돌기
      # 시작하는 순간, try는 죽은 방어가 아니라 진짜로 응답을 지키는 코드가 된다 —
      # 그때쯤이면 Task 6이 workspace_id/AuthUser 자체를 지웠을 가능성이 높지만.
      workspace_id: Current.user.try(:workspace_id),
      request_id: controller.request.request_id
    }
  end
end
