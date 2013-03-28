require 'chef_webui/knife'

class Chef
  class Knife
    class OrganizationCreate < ChefWebui::Knife
      banner "knife organization create ORGNAME"

      common_options

      option :validator_key_file,
        :short => '-f VALIDATOR_KEY_FILE',
        :long => '--file VALIDATOR_KEY_FILE'

      def configure_chef
        super
        init_config_variable(:validator_key_file)
      end

      def run
        if name_args.length == 0
          ui.error("Must specify organization name to create as the first argument, i.e. knife organization create ORGNAME")
          exit 1
        end
        organization = name_args[0]

        output "Creating organization #{organization} ..."
        begin
          webui_session.create_org(organization)
          if Chef::Config[:validator_key_file]
            output "Creating validator file #{validator_key_file}"
            user_key = webui_session.regenerate_validator_key
            File.open(Chef::Config[:validator_key_file], 'w') do |file|
              file.write(user_key)
            end
          end
        rescue
        end
      end
    end
  end
end
