# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport/base'

module Bolt
  class Config
    module Transport
      module Async
        class Filesystem < Bolt::Config::Transport::Base
          OPTIONS = %w[
          base_path
          recv_dir
          send_dir
          ].freeze

          DEFAULTS = {
            'recv_dir' => 'recv',
            'send_dir' => 'send',
            'runas' => 'self'
          }

          if const_defined?('Puppet') && Puppet.settings[:vardir]
            DEFAULTS['base_path'] = Puppet.settings[:vardir]
          else
            read, write = IO.pipe

            fork do
              require 'puppet'

              Puppet.initialize_settings([], false)

              write.print("#{Puppet.settings[:vardir]}")
            end

            Process.wait
            write.close
            DEFAULTS['base_path'] = read.read
            read.close

            if DEFAULTS['base_path'].strip.empty?
              require 'tmpdir'

              DEFAULTS['base_path'] = Dir.tmpdir
            end
          end

          DEFAULTS['base_path'] = File.join(DEFAULTS['base_path'], 'bolt', 'transport', 'filesystem')

          DEFAULTS.freeze
        end
      end
    end
  end
end
