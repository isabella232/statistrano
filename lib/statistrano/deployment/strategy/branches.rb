module Statistrano
  module Deployment
    module Strategy

      #
      # Branches is for deployments that depend upon the
      # current git branch, eg. doing feature branch deployments
      #
      class Branches < Base
        register_strategy :branches

        option :base_domain
        option :public_dir, :call, Proc.new { Asgit.current_branch.to_slug }
        option :post_deploy_task,  Proc.new { |d| d.generate_index }

        task :list,           :list_releases,  "List branches"
        task :prune,          :prune_releases, "Prune a branch"
        task :generate_index, :generate_index, "Generate a branch index"
        task :open,           :open_url,       "Open the current branch URL"

        def deploy
          unless safe_to_deploy?
            Log.error "exiting due to git check failing"
            abort()
          end

          exit_if_deployments_active
          invoke_build_task

          make_deployment_active
          releaser.create_release remote

          manifest.put Release.new( config.public_dir, config ).to_hash, :name
          manifest.save!

          invoke_post_deploy_task
          make_deployment_inactive
        end

        # output a list of the releases in manifest
        # @return [Void]
        def list_releases
          sorted_release_data.each do |release|
            Log.info "#{release[:name]} created at #{Time.at(release[:time]).strftime('%a %b %d, %Y at %l:%M %P')}"
          end
        end

        # trim releases not in the manifest,
        # get user input for removal of other releases
        # @return [Void]
        def prune_releases
          make_deployment_active
          prune_untracked_releases

          if get_releases && get_releases.length > 0
            pick_and_remove_release
          else
            Log.warn "no releases to prune"
          end
          make_deployment_inactive
        end

        # generate an index file for releases in the manifest
        # @return [Void]
        def generate_index
          index_dir  = File.join( config.remote_dir, "index" )
          index_path = File.join( index_dir, "index.html" )
          remote.create_remote_dir index_dir
          remote.run "touch #{index_path} && echo '#{release_list_html}' > #{index_path}"
        end

        private

          def remote
            remotes.first
          end

          def manifest
            @_manifest ||= Deployment::Manifest.new remote_overridable_config(:remote_dir, remote), remote
          end

          def remote_overridable_config option, remote
            (remote && remote.config.public_send(option)) || config.public_send(option)
          end

          def pick_and_remove_release
            picked_release = pick_release_to_remove
            if picked_release
              remove_release(picked_release)
              generate_index
            else
              Log.warn "sorry, that isn't one of the releases"
            end
          end

          def pick_release_to_remove
            list_releases_with_index

            picked_release = Shell.get_input("select a release to remove: ").gsub(/[^0-9]/, '')

            if !picked_release.empty? && picked_release.to_i < get_releases.length
              return get_releases[picked_release.to_i]
            else
              return false
            end
          end

          def list_releases_with_index
            get_releases.each_with_index do |release,idx|
              Log.info :"[#{idx}]", "#{release}"
            end
          end

          # removes releases that are on the remote but not in the manifest
          # @return [Void]
          def prune_untracked_releases
            get_actual_releases.each do |release|
              remove_release(release) unless get_releases.include? release
            end
          end

          def release_list_html
            releases = sorted_release_data.map do |r|
              name = r.fetch(:name)
              r.merge({ repo_url: config.repo_url }) if config.repo_url
              Release.new( name, config, r )
            end

            Index.new( releases ).to_html
          end

          def sorted_release_data
            manifest.data.sort_by do |r|
              r[:time]
            end.reverse
          end

          # remove a release
          # @param name [String]
          # @return [Void]
          def remove_release name
            Log.info "Removing release '#{name}'"
            remote.run "rm -rf #{release_path(name)}"
            manifest.remove_if do |r|
              r[:name] == name
            end
            manifest.save!
          end

          # return array of releases from the manifest
          # @return [Array]
          def get_releases
           sorted_release_data.map { |r| r[:name] }
          end

          # return array of releases on the remote
          # @return [Array]
          def get_actual_releases
            releases = []
            resp = remote.run("ls -mp #{config.remote_dir}")
            releases = resp.stdout.strip.split(',')
            releases.keep_if { |release| /\/$/.match(release) }
            releases.map { |release| release.strip.gsub(/(\/$)/, '') }.keep_if { |release| release != "index" }
          end

          # path to the current release
          # this is based on the git branch
          # @return [String]
          def current_release_path
            File.join( config.remote_dir, config.public_dir )
          end

          # path to a specific release
          # @return [String]
          def release_path name
            File.join( config.remote_dir, name )
          end

          # open the current checked out branch
          # @return [Void]
          def open_url
            if config.base_domain
              url = "http://#{config.public_dir}.#{config.base_domain}"
              system "open #{url}"
            end
          end

      end

    end
  end
end

require_relative 'branches/index'
require_relative 'branches/release'