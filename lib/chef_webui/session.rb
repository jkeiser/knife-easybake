require 'mechanize'
require 'chef_webui/webui_error'

module ChefWebui
  class Session
    attr_reader :manage_url
    attr_reader :account_url

    def initialize(manage_url, account_url)
      @manage_url = manage_url
      @account_url = account_url
      @agent = Mechanize.new
      @agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      get('login')
    end

    def login(username, password)
      results = post('login_exec',
        {
          'name' => username,
          'password' => password,
          'commit' => 'Login'
        })

      if !logged_in
        raise_webui_error
      end
    end

    def logged_in
      return @agent.page.content =~ /Logged in as/
    end

    def create_org(orgname)
      post('organizations',
        {
          'id' => orgname,
          'full_name' => orgname
        })
    end

    def switch_to_org(orgname)
      post("organizations/#{orgname}/select", {})
    end

    def create_user(username, password, first_name, last_name, email)
      post('users',
        {
          'authenticity_token' => @authenticity_token,
          'user[username]' => username,
          'user[first_name]' => first_name,
          'user[last_name]' => last_name,
          'user[email]' => email,
          'user[password]' => password,
          'user[password_confirmation]' => password,
          'commit' => 'Submit'
        })
      if !@agent.page.content =~ /Your Private Chef user account has been created./
        raise_webui_error
      end
    end

    def regenerate_validator_key(orgname)
      @agent.post("#{manage_url}/organizations/#{orgname}/_regenerate_key",
        {
          '_method' => 'put',
          'authenticity_token' => @authenticity_token
        }).content
    end

    def regenerate_user_key
      hosted_key = @agent.post("#{account_url}/account/regen_key",
        {
          'commit' => 'Get a new key',
          'authenticity_token' => @authenticity_token
        }).content
      return hosted_key if hosted_key =~ /-----BEGIN RSA PRIVATE KEY-----/
      private_key = @agent.post("#{account_url}/users/#{current_user}/_regen_key",
        {
          'commit' => 'Get a new key',
          'authenticity_token' => @authenticity_token
        }).content
      return private_key if private_key =~ /-----BEGIN RSA PRIVATE KEY-----/
      raise_webui_error
    end

    def organizations
      get('organizations')
      result = []
      @agent.page.search('#all_associated_organizations td.name_column').each do |org|
        result << org.text.gsub(/\s+/, ' ')
      end
      result
    end

    def current_user
      @agent.page.at('#user-navigation a').text.gsub(/\s+/, ' ')
    end

    def current_org
      @agent.page.at('#header h1 a[href="/nodes"]').text.gsub(/\s+/, ' ')
    end

    def current_environment
      @agent.page.at('#Environment option[selected="selected"]').text.gsub(/\s+/, ' ')
    end

    private

    def post(relative_url, parameters)
      parameters['authenticity_token'] = @authenticity_token
      result = @agent.post("#{manage_url}/#{relative_url}", parameters)
      retrieve_authenticity_token
      result
    end

    def get(relative_url)
      result = @agent.get("#{manage_url}/#{relative_url}")
      retrieve_authenticity_token
      result
    end

    def retrieve_authenticity_token
      begin
        @authenticity_token = @agent.page.search('//meta[@name="csrf-token"]/@content').text
      rescue
      end
    end

    def retrieve_error_text
      error_messages = @agent.page.search('//span[@class="validation-error"]/..').to_a
      error_messages += @agent.page.search('//div[@class="message error"]/p').to_a

      if error_messages.count > 0
        error_text = ""
        error_messages.each do |em|
          error_text << "#{em.text.gsub(/\s+/, ' ')}\n" # get rid of whitespace
        end
      else
        error_text << em.body
      end
      error_text
    end

    def raise_webui_error
      raise WebuiError.new, "Account not created:\n#{retrieve_error_text}"
    end
  end
end
