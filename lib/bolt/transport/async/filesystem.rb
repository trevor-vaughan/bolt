# frozen_string_literal: true

require 'bolt/transport/base'
require_relative 'filesystem/connection'

module Bolt
  module Transport
    module Async
      class Filesystem < Bolt::Transport::Base
        attr_reader :connection
        attr_reader :run_id

        def initialize(*args)
          require 'date'

          @connections = {}
          @run_id = DateTime.now.strftime('%Q').to_i

          super(*args)
        end

        def connected?(target)
          @connections[target.name] ||= Connection.new(target, logger)
          @connections[target.name].connected?
        end

        def get_connection(target)
          connected?(target)
          @connections[target.name]
        end

        def run_command(target, command, options = {}, position = [])

          connection = nil
          # Send the command
          begin
            connection = get_connection(target)
            connection.send_message(format_message(target, 'run_command', command))
          rescue StandardError => e
            return Bolt::Result.from_exception(target, e, action: 'run_command')
          end

          # Pretend there is a remote host doing something
          begin
            connection.run_commands(run_id)
          rescue StandardError => e
            return Bolt::Result.from_exception(target, e, action: 'run_command')
          end

          # Get the results
          connection.recv_message(run_id)
        end

        private

        def format_message(target, action, content, options = {})
          message = {
            version: '0.0.1',
            run_id: run_id,
            target: target.name,
            action: action,
            transport: 'filesystem',
            security: 'none',
            runas: Puppet::Etc.getpwuid(Process.uid).name,
            encoding: 'none',
            body: {
              content: content,
              options: options
            }
          }

          message.to_json
        end
      end
    end
  end
end
