# frozen_string_literal: true

module Bolt
  module Transport
    class RabbitMQ < Base
      class Connection
        def initialize(target, *args)
          require 'bunny'

          conn = Bunny.new("amqp://#{target.options['user']}:#{target.options['pass']}@#{target.options['server']}:#{target.options['port']}")
          conn.start

          channel = conn.create_channel
          @exchange = channel.fanout('bolt.command')
          @queue = channel.queue('bolt_client', :auto_delete => true).bind(@exchange)

          at_exit{conn.close}
        end

        def run_command(targets, command, options = {}, position = [])
          body = {
            'run_command' => {
              'command' => command,
              'options' => options
            }
          }.to_json

          @exchange.publish(body, :expiration => 10000)

          puts 'here'
        end
      end
    end
  end
end
