# frozen_string_literal: true

module ActionMCP
  module Transport
    module Prompts
      def send_prompts_list(request_id)
        prompts = format_registry_items(PromptsRegistry.non_abstract)
        send_jsonrpc_response(request_id, result: { prompts: prompts })
      end

      def send_prompts_get(request_id, prompt_name, params)
        result = PromptsRegistry.prompt_call(prompt_name.to_s, params)
        if result.is_error
          send_jsonrpc_response(request_id, error: result)
        else
          send_jsonrpc_response(request_id, result:)
        end
      end
    end
  end
end
