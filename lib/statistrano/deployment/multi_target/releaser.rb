module Statistrano
  module Deployment
    class MultiTarget

      class Releaser
        extend ::Statistrano::Config::Configurable

        option :release_count, 5
        option :release_dir, "releases"
        option :public_dir,  "current"

        attr_reader :release_name

        def initialize options={}
          config.options.each do |opt,val|
            config.send opt, options.fetch(opt,val)
          end

          @release_name = Time.now.to_i.to_s
        end

      end

    end
  end
end