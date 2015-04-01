module ActiveRestClient
  class Logger
    @logfile = nil
    @messages = []

    def self.logfile=(value)
      @logfile = value
    end

    def self.messages
      @messages
    end

    def self.reset!
      @logfile = nil
      @messages = []
    end

    def self.debug(message)
      if defined?(Rails) && Rails.respond_to?(:logger)
        Rails.logger.debug(message)
      elsif @logfile
        File.open(@logfile, "a") do |f|
          f << "#{message}\n"
        end
      else
        @messages << message
      end
    end

    def self.info(message)
      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger.info(message)
      elsif @logfile
        File.open(@logfile, "a") do |f|
          f << "#{message}\n"
        end
      else
        @messages << message
      end
    end

    def self.warn(message)
      if defined?(Rails) && Rails.respond_to?(:logger)
        Rails.logger.warn(message)
      elsif @logfile
        File.open(@logfile, "a") do |f|
          f << "#{message}\n"
        end
      else
        @messages << message
      end
    end

    def self.error(message)
      if defined?(Rails) && Rails.respond_to?(:logger)
        Rails.logger.error(message)
      elsif @logfile
        File.open(@logfile, "a") do |f|
          f << "#{message}\n"
        end
      else
        @messages << message
      end
    end
  end
end
