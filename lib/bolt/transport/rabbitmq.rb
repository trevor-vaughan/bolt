# frozen_string_literal: true

require 'base64'
require 'find'
require 'json'
require 'pathname'
require 'bolt/transport/base'
require 'bolt/transport/rabbitmq/connection'

module Bolt
  module Transport
    class RabbitMQ < Base
      def run_command(*args)
        conn = Connection.new(*args)

        conn.run_command(*args)
      end
    end
  end
end
