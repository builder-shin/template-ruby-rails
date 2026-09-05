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
      # user_id·remote_ip·request_id가 전혀 없다. 이 자리를 무너뜨려도 어떤
      # 테스트도 잡지 못한다 — 죽은 코드를 고정할 테스트는 없다.
      #
      # workspace_id는 여기서 빠졌다. 그것은 외부 인증 서비스가 돌려주던 사용자
      # 표현에만 있던 속성이고, C2가 그 모델과 호출 경로를 통째로 지웠다.
      # Current.user는 이제 항상 User이며 User에는 그런 개념이 없다.
      request_id: controller.request.request_id
    }
  end
end
