# Every non-2xx response is rendered as `{"error": "<message>"}`.
class ApiError < StandardError
  attr_reader :status

  def initialize(status, message)
    super(message)
    @status = status
  end

  def self.bad_request(message) = new(:bad_request, message)
  def self.not_found(message = "not found") = new(:not_found, message)
  def self.unprocessable(message) = new(:unprocessable_content, message)
end
