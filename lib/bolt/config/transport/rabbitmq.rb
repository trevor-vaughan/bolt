# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport/base'

module Bolt
  class Config
    module Transport
      class RabbitMQ < Base
        OPTIONS = %w[
          user
          pass
          server
          port
        ].freeze

        DEFAULTS = {
          "task-environment" => "production"
        }.freeze
      end
    end
  end
end
