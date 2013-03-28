require 'chef_webui/knife'

class Chef
  class Knife
    class UserRekey < ChefWebui::Knife
      banner "knife user rekey"

      common_options

      option :key_file,
        :short => '-f KEY_FILE',
        :long => '--file KEY_FILE',
        :required => true,
        :description => 'File to output to (i.e. username.pem)'

      def configure_chef
        super
        init_config_variable(:key_file)
      end

      def run
        if name_args.length == 0
          ui.error("Must specify organization name to create as the first argument, i.e. knife organization create ORGNAME")
          exit 1
        end
        webui_session.regenerate_validation_key(name_args[1])
        File.open(Chef::Config[:validator_key_file], 'w') do |file|
          file.write(validation_key)
        end
      end
    end
  end
end
