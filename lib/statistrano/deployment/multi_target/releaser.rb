module Statistrano
  module Deployment
    class MultiTarget

      class Releaser
        extend ::Statistrano::Config::Configurable

        options :remote_dir, :local_dir

        option :release_count, 5
        option :release_dir, "releases"
        option :public_dir,  "current"

        attr_reader :release_name

        def initialize options={}
          config.options.each do |opt,val|
            config.send opt, options.fetch(opt,val)
          end

          check_required_options :remote_dir, :local_dir
          @release_name = Time.now.to_i.to_s
        end

        def setup_release_path target
          target.create_remote_dir release_path
        end

        def rsync_to_remote target
          target.rsync_to_remote local_path, release_path
        end

        def symlink_release target
          target.run "ln -nfs #{release_path} #{public_path}"
        end

        private

          def check_required_options *opts
            opts.each do |opt|
              raise ArgumentError, "a #{opt} is required" unless config.public_send(opt)
            end
          end

          def local_path
            File.join( Dir.pwd, config.local_dir )
          end

          def release_path
            File.join( config.remote_dir, config.release_dir, release_name )
          end

          def public_path
            File.join( config.remote_dir, config.public_dir )
          end

      end

    end
  end
end