class ApplicationJob < ActiveJob::Base
  # Sidekiq adds UniformInteger(0, 10 * (count + 1) - 1) seconds. With this
  # exponential base, all backends retry after 15..24, 30..49 and 60..89 seconds.
  sidekiq_retry_in { |count| 15 * (2**count) }

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
