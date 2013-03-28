require 'chef_webui/knife'
require 'fileutils'

class Chef
  class Knife
    class Setup < ChefWebui::Knife
      banner "knife setup ORGNAME"

      common_options

      option :chef_repo_path,
        :long => '--chef-repo-path PATH',
        :description => 'Path to workstation directory (workstation files will go in PATH/.chef directory)'

      option :regen_user_key,
        :long => '--[no-]regen-user-key',
        :boolean => true,
        :description => "Tell setup to regenerate the user key.  Default: false"

      option :regen_validator_key,
        :long => '--[no-]regen-validator-key',
        :boolean => true,
        :description => "Tell setup to regenerate the validator key.  Default: false"

      option :validation_key,
        :short        => "-K KEY_FILE",
        :long         => "--validation_key KEY_FILE",
        :description  => "Set the validation key file location, used for registering new clients"

      option :validation_client_name,
        :short        => "-U NAME",
        :long         => "--validation-client-name NAME",
        :description  => "Set the validation client name, used for registering new clients"

      option :api_server_url,
        :long => '--api-server-url URL',
        :description => 'Set the API server URL (default: https://api.opscode.com)'

      def configure_chef
        super
        init_config_variable(:chef_repo_path)
        init_config_variable(:validation_key)
        init_config_variable(:validation_client_name)
        init_config_variable(:api_server_url)
      end

      def run
        if name_args.length == 0
          ui.error("Must specify organization name to create as the first argument, i.e. knife organization create ORGNAME")
          exit 1
        end

        organization = name_args[0]

        # Get validator key
        if config[:regen_validator_key]
          output "Regenerating validation key for #{organization}-validator..."
          validation_key = webui_session.regenerate_validator_key(organization)
        elsif Chef::Config[:validation_client_name] == "#{organization}-validator" &&
              Chef::Config[:validation_key] && File.exist?(Chef::Config[:validation_key])
          output "Copying validation key from #{Chef::Config[:validation_key]} ..."
          validation_key = IO.read(Chef::Config[:validation_key])
        else
          ui.error <<-EOM
Validator key file for #{organization}-validator not found.
If you don't have a key, pass --regen-validator-key to regenerate it.
If you have a key, pass -U #{organization}-validator and (optionally) -K VALIDATOR_KEY_FILE.
EOM
          exit 1
        end

        # Get user key
        if config[:regen_user_key]
          output "Regenerating user key for #{Chef::Config[:username]} ..."
          user_key = webui_session.regenerate_user_key
        elsif Chef::Config[:node_name] == "#{Chef::Config[:username]}" &&
              Chef::Config[:client_key] && File.exist?(Chef::Config[:client_key])
          output "Copying user key from #{Chef::Config[:client_key]} ..."
          user_key = IO.read(Chef::Config[:client_key])
        else
          ui.error <<-EOM
User key file for #{Chef::Config[:username]} not found.
If you don't have a key, pass --regen-user-key to regenerate it.
If you have a key, pass -u #{Chef::Config[:username]} and -k YOUR_KEY_FILE.
EOM
          exit 1
        end

        # Write out client client.rb
        client_rb_file = "#{File.dirname(Chef::Config[:validation_key])}/client.rb"
        if File.exist?(client_rb_file)
          output "client.rb file #{client_rb_file} already exists.  Skipping ..."
        else
          output "Writing #{client_rb_file} ..."
          write_file(client_rb_file, <<-EOM)
current_dir = File.dirname(__FILE__)
require 'socket'
log_level                :info
log_location             STDOUT
validation_client_name   "#{organization}-validator"
chef_server_url          "#{Chef::Config[:api_server_url]}/organizations/#{organization}"
client_key               "\#{current_dir}/\#{Socket.gethostname}.pem"
EOM
        end

        # Write out client validation.pem
        if File.exist?(Chef::Config[:validation_key]) && !config[:regen_validator_key]
          output "Validation key #{Chef::Config[:validation_key]} already exists.  Skipping creation ..."
        else
          output "Writing #{Chef::Config[:validation_key]} ..."
          write_file(Chef::Config[:validation_key], validation_key)
        end

        if !Chef::Config[:chef_repo_path]
          ui.error("You must pass --chef-repo-path PATH (specify the place you want to run knife from)")
          exit 1
        end

        # Write out workstation knife.rb
        client_rb_file = "#{Chef::Config[:chef_repo_path]}/.chef/knife.rb"
        if File.exist?(client_rb_file)
          output "client.rb file #{client_rb_file} already exists.  Skipping ..."
        else
          output "Writing #{client_rb_file} ..."
          write_file(client_rb_file, <<-EOM)
current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                "#{Chef::Config[:username]}"
client_key               "\#{current_dir}/#{Chef::Config[:username]}.pem"
validation_client_name   "#{organization}-validator"
validation_client_key    "\#{current_dir}/#{organization}-validator.pem"
chef_server_url          "https://api.opscode.com/organizations/#{organization}"
EOM
        end

        # Write out workstation user.pem
        user_pem_file = "#{Chef::Config[:chef_repo_path]}/.chef/#{Chef::Config[:username]}.pem"
        if File.exist?(user_pem_file) && !config[:regen_user_key]
          output "User key #{user_pem_file} already exists.  Skipping creation ..."
        else
          output "Writing #{user_pem_file} ..."
          write_file(user_pem_file, user_key)
        end

        # Write out workstation validator.pem
        workstation_validator_file = "#{Chef::Config[:chef_repo_path]}/.chef/#{organization}-validator.pem"
        if File.exist?(workstation_validator_file) && !config[:regen_validator_key]
          output "Validation key #{workstation_validator_file} already exists.  Skipping creation ..."
        else
          output "Writing #{workstation_validator_file} ..."
          write_file(workstation_validator_file, validation_key)
        end
      end

      def write_file(filename, contents)
        FileUtils.mkdir_p(File.dirname(filename))
        File.open(filename, 'w') do |file|
          file.write(contents)
        end
      end
    end
  end
end
