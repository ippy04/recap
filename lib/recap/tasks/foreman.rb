# These tasks configure recap to use Foreman to stop, start and restart your application processes.

require 'recap/tasks/deploy'

module Recap::Tasks::Foreman
  extend Recap::Support::Namespace

  namespace :foreman do
    # Processes are declared in a `Procfile`, by default in the root of the application directory.
    _cset(:procfile) { "Procfile" }

    # Foreman startup scripts are exported in `upstart` format by default.
    _cset(:foreman_export_format, "upstart")

    # Foreman startup scripts are generated based on the standard templates by default
    _cset(:foreman_template, nil)

    _cset(:foreman_template_option) { foreman_template ? "--template #{foreman_template}" : nil}

    # Scripts are exported (as the the application user) to a temporary location first.
    _cset(:foreman_tmp_location) { "#{deploy_to}/tmp/foreman" }

    # After exports, the scripts are moved to their final location, usually `/etc/init`.
    _cset(:foreman_export_location, "/etc/init")

    # The standard foreman export.
    _cset(:foreman_export_command) { "./bin/foreman export #{foreman_export_format} #{foreman_tmp_location} --procfile #{procfile} --app #{application} --user #{application_user} --log #{deploy_to}/log #{foreman_template_option}" }

    namespace :export do
      # After each deployment, the startup scripts are exported if either the `Procfile` or any custom Foreman templates have changed.
      task :if_changed do
        if trigger_update?(procfile) || (foreman_template && trigger_update?(foreman_template))
          top.foreman.export.default
        end
      end

      # To export the scripts, they are first generated in a temporary location, then copied to their final
      # destination.  This is done because the foreman export command needs to be run as the application user,
      # while sudo is required to write to `/etc/init`.
      desc 'Export foreman configuration'
      task :default do
        if deployed_file_exists?(procfile)
          sudo "mkdir -p #{deploy_to}/log"
          sudo "chown #{application_user}: #{deploy_to}/log"
          as_app foreman_export_command
          sudo "rm -f #{foreman_export_location}/#{application}*"
          sudo "cp #{foreman_tmp_location}/* #{foreman_export_location}"
        end
      end
    end

    # Starts all processes that form the application.
    desc 'Start all application processes'
    task :start do
      if deployed_file_exists?(procfile)
        sudo "start #{application}"
      end
    end

    # Restarts all processes that form the application.
    desc 'Restart all application processes'
    task :restart do
      if deployed_file_exists?(procfile)
        sudo "restart #{application} || sudo start #{application}"
      end
    end

    # Stops all processes that form the application.
    desc 'Stop all application processes'
    task :stop do
      if deployed_file_exists?(procfile)
        sudo "stop #{application}"
      end
    end

    after 'deploy:update_code', 'foreman:export:if_changed'
    after 'deploy:restart', 'foreman:restart'
  end
end
