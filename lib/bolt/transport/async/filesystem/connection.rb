# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'tempfile'
require 'bolt/node/output'
require 'bolt/util'

module Bolt
  module Transport
    module Async
      class Filesystem < Bolt::Transport::Base
        class Connection
          attr_reader :user, :logger, :target

          def initialize(target, logger)
            @target = target
            # The familiar problem: Etc.getlogin is broken on osx
            @user = ENV['USER'] || Etc.getlogin
            @logger = logger

            require 'fileutils'

            unless Puppet::Util.absolute_path?(target.options['send_dir'])
              @target.options['send_dir'] = File.join(target.options['base_path'], target.options['send_dir'], target.name)
            end

            unless Puppet::Util.absolute_path?(target.options['recv_dir'])
              @target.options['recv_dir'] = File.join(target.options['base_path'], target.options['recv_dir'], target.name)
            end

            @logger.debug { "Transport:filesystem - Creating send directory '#{@target.options['send_dir']}'" }
            FileUtils.mkdir_p(@target.options['send_dir'])

            @logger.debug { "Transport:filesystem - Creating receive directory '#{@target.options['recv_dir']}'" }
            FileUtils.mkdir_p(@target.options['recv_dir'])
          end

          def connected?
            errors = []

            unless File.writable?(@target.options['send_dir'])
              errors << "Cannot open #{@target.options['send_dir']}"
            end

            unless File.writable?(@target.options['recv_dir'])
              errors << "Cannot open #{@target.options['recv_dir']}"
            end

            unless errors.empty?
              raise(StandardError, error.join("\n"))
            end
          end

          def send_message(body)
            require 'date'

            File.open(File.join(@target.options['send_dir'], "#{DateTime.now.strftime('%Q')}.msg"), 'w') do |fh|
              fh.puts(body)
            end
          end

          def recv_message(run_id)
            result = Bolt::Result.from_exception(@target, StandardError.new('No output found'), action: 'unknown')

            Dir.glob(File.join(@target.options['recv_dir'], '*')).each do |msg|
              begin
                require 'json'

                msg_content = JSON.load(File.read(msg))

                next unless msg_content && (msg_content['run_id'] == run_id) && (msg_content['target'] == @target.name)

                msg_result = JSON.load(msg_content['result'])

                # Super fragile but Bolt::Result doesn't have a loader
                msg_result.delete('target')
                msg_result.delete('status')

                result = Bolt::Result.new(@target, msg_result.transform_keys(&:to_sym))

                File.unlink(msg)
              rescue StandardError => e
                result = Bolt::Result.from_exception(@target, e, action: 'recv_message')
              end
            end

            result
          end

          def run_commands(run_id)
            result = Bolt::Result.from_exception(@target, StandardError.new('No command was run'), action: 'unknown')

            Dir.glob(File.join(@target.options['send_dir'], '*')).each do |msg|
              begin
                require 'json'

                msg_content = JSON.load(File.read(msg))

                next unless msg_content && (msg_content['run_id'] == run_id) && (msg_content['target'] == @target.name)

                runner = Bolt::Transport::Local.new

                if msg_content['action'] == 'run_command'
                  begin
                    result = runner.run_command(@target, msg_content['body']['content'], msg_content['body']['options'])
                    File.unlink(msg)
                  rescue StandardError => e
                    result = Bolt::Result.from_exception(@target, e, action: msg_content['action'])
                  end
                end
              rescue StandardError => e
                result = Bolt::Result.from_exception(@target, e, action: msg_content['action'])
              end
            end

            require 'date'

            File.open(File.join(@target.options['recv_dir'], "#{DateTime.now.strftime('%Q')}.msg"), 'w') do |fh|
              message_content = {
                version: '0.0.1',
                run_id: run_id,
                target: @target.name,
                result: result.to_json
              }

              fh.puts(message_content.to_json)
            end
          end
        end
      end
    end
  end
end
