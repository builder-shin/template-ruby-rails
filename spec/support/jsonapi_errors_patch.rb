ApplicationController.rescue_from(
  StandardError,
  with: :render_jsonapi_internal_server_error,
)

ApplicationController.subclasses.each do |controller|
  old_rescue_handlers = controller.rescue_handlers
  controller.rescue_from(
    StandardError,
    with: :render_jsonapi_internal_server_error,
  )
  controller.rescue_handlers = (controller.rescue_handlers - old_rescue_handlers) + old_rescue_handlers
end
