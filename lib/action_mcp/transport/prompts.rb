# app/concerns/action_mcp/transport/prompts.rb
module ActionMCP
  module Transport
    module Prompts
      def send_prompts_list(request_id)
        prompts = format_registry_items(PromptsRegistry.non_abstract)
        send_jsonrpc_response(request_id, result: { prompts: prompts })
      end

      def send_prompts_get(request_id, prompt_name, params)
        send_jsonrpc_response(request_id, result: PromptsRegistry.prompt_call(prompt_name.to_s, params))
      rescue RegistryBase::NotFound
        send_jsonrpc_response(request_id, error: JsonRpc::JsonRpcError.new(
          :method_not_found,
          message: "Prompt not found: #{prompt_name}"
        ).as_json)
      end
    end
  end
end
