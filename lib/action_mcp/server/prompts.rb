# frozen_string_literal: true

module ActionMCP
  module Server
    module Prompts
      include ResultResponse

      def send_prompts_list(request_id, params = {})
        page, next_cursor = paginate(session.registered_prompts, cursor: params["cursor"])

        result = { prompts: page.map(&:to_h) }
        result[:nextCursor] = next_cursor if next_cursor

        send_jsonrpc_response(request_id, result: result)
      rescue Server::CursorError => e
        send_jsonrpc_error(request_id, :invalid_params, e.message)
      end

      def send_prompts_get(request_id, prompt_name, params, _meta = {})
        # Find prompt in session's registry
        prompt_class = session.registered_prompts.find { |p| p.prompt_name == prompt_name }

        if prompt_class
          # Create prompt and set execution context
          prompt = prompt_class.new(params)
          prompt.with_context({ session: session, request: { params: { name: prompt_name, _meta: _meta } } })

          result = DevReloader.wrap { prompt.call }

          send_result_response(request_id, result)
        else
          send_jsonrpc_error(request_id, :invalid_params, "Prompt '#{prompt_name}' not available in this session")
        end
      rescue ArgumentError, ActiveModel::UnknownAttributeError => e
        send_jsonrpc_error(request_id, :invalid_params, e.message)
      end
    end
  end
end
