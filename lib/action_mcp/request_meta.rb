# frozen_string_literal: true

module ActionMCP
  module RequestMeta
    def request_meta
      params = execution_context.dig(:request, :params)
      meta = params && (params[:_meta] || params["_meta"])
      meta.is_a?(Hash) ? meta.with_indifferent_access : ActiveSupport::HashWithIndifferentAccess.new
    end
  end
end
