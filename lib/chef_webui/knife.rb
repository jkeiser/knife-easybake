require 'chef/knife'
require 'chef_webui/session'
require 'highline/import'

module ChefWebui
  class Knife < Chef::Knife
    def self.common_options
      option :username,
        :long => '--username USERNAME',
        :description => 'Hosted Chef Username'

      option :password,
        :long => '--password PASSWORD',
        :description => 'Hosted Chef Password'

      option :manage_url,
        :long => '--manage-url URL',
        :description => 'Hosted Chef Manage URL (default: https://manage.opscode.com)'

      option :account_url,
        :long => '--account-url URL',
        :description => 'Hosted Chef Account URL (default: https://www.opscode.com)'
    end

    def init_config_variable(variable_name, default = nil)
      Chef::Config[variable_name] = config[variable_name] if config[variable_name]
      if default
        Chef::Config[variable_name] ||= default
      end
    end

    def configure_chef
      super
      init_config_variable(:manage_url, 'https://manage.opscode.com')
      init_config_variable(:account_url, 'https://www.opscode.com')
      init_config_variable(:username)
      init_config_variable(:password)
    end

    def webui_session
      @webui_session ||= begin
        if !Chef::Config[:username]
          Chef::Config[:username] = ask("Enter your username:")
        end
        if !Chef::Config[:password]
          Chef::Config[:password] = ask("Enter your password:") { |q| q.echo = '*' }
        end
        session = ChefWebui::Session.new(Chef::Config[:manage_url], Chef::Config[:account_url])
        session.login(Chef::Config[:username], Chef::Config[:password])
        session
      end
    end
  end
end
