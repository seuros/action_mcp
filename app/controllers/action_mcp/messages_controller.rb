module ActionMCP
  class MessagesController < ApplicationController
    # @route POST /sse (sse_in)
    def create
      session_id = params[:session_id]

      transport = TransportRegistry.get(session_id)

      unless transport
        error_msg = "Session not found: #{session_id}"
        render status: :not_found, json: { error: error_msg }
        return
      end

      begin
        transport.handle_post_message(request, response)
      rescue => e
        Rails.logger.error "Error handling message: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        render status: :internal_server_error, json: { error: e.message }
      end
    end
  end
end
