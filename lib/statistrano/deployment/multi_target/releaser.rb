module Statistrano
  module Deployment
    class MultiTarget

      class Releaser
        extend ::Statistrano::Config::Configurable

        option :remote_dir
        option :release_count, 5
        option :release_dir, "releases"
        option :public_dir,  "current"

        attr_reader :release_name

        def initialize options={}
          config.options.each do |opt,val|
            config.send opt, options.fetch(opt,val)
          end

          raise ArgumentError, "a remote_dir is required" unless config.remote_dir
          @release_name = Time.now.to_i.to_s
        end

        def setup_release_path target
          target.create_remote_dir release_path
        end

        private

          def release_path
            File.join( config.remote_dir, config.release_dir, release_name )
          end

      end

    end
  end
end