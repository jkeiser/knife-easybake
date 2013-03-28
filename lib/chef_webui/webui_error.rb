module ChefWebui
  class WebuiError < StandardError
    def initialize(cause = nil)
      @cause = cause
    end

    attr_reader :cause
  end
end
