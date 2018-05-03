class ErrorHandler

  # Displays the error 403 page for the user. (Service Denied)
  #
  # @param app [Instance] The instance for the app.rb.
  # @param msg [String] Message to display for user. Set to nil if it shall use the default message.
  # @return [String] Returns the error 403 page with supplied message.
  def self.e_403(app, message)
    app.status(403)

    if message.nil? || message.empty?
      msg = "Du har inte behörighet till <b>#{app.request.path_info}</b>.<br>Testa att logga in och försök igen."
    else
      msg = message.to_s
    end
    if app.settings.production?
      Logs.create({:type => Logs::ERROR_LOG,
                   :code=>403,
                   :message => msg,
                   :description => nil,
                   :stacktrace => nil,
                   :path => app.request.path_info,
                   :ip => app.request.ip,
                   :datetime => Time.new.strftime('%Y-%m-%d_%H:%M:%S')
                  })
    end
    app.slim :error_page, :locals => {:error_code => '403', :error_msg => msg}
  end

  # Displays the error 404 page for the user. (Resource not found)
  #
  # @param app [Instance] The instance for the app.rb.
  # @param msg [String] Message to display for user. Set to nil if it shall use the default message.
  # @return [String] Returns the error 404 page with supplied message.
  def self.e_404(app, message)
    #app.status 404
    error_msg("(404) -- #{app.request.ip} Unknown resource: #{app.request.path_info}")

    if message.nil? || message.empty?
      msg = "Ledsen kompis men kunde inte hitta: <b>#{app.request.path_info}</b>"
    else
      msg = message.to_s
    end
    if app.settings.production?
      Logs.create({:type => Logs::ERROR_LOG,
                   :code=>404,
                   :message => msg,
                   :description => nil,
                   :stacktrace => nil,
                   :path => app.request.path_info,
                   :ip => app.request.ip,
                   :datetime => Time.new.strftime('%Y-%m-%d_%H:%M:%S')
                  })
    end
    app.slim :error_page, :locals => {:error_code => '404', :error_msg => msg}
  end

  # Displays the error 500 page for the user. (Internal server error)
  #
  # @param app [Instance] The instance for the app.rb.
  # @param msg [String] Message to display for user. Set to nil if it shall use the default message.
  # @return [String] Returns the error 500 page with supplied message.
  def self.e_500(app, *args)
    app.status 500
    error_msg("(500) -- #{app.request.ip} Internal server error: #{app.request.path_info}")
    if args[0].nil? || args.nil?
      msg = 'Ojdå.. Något hände! En rapport har skapats angående felet.'
    else
      msg = arg[0].to_s
    end
    if app.settings.production?
      error = nil
      unless args[1].nil? && args.nil?
        error = args[1]
      end
      Logs.create({:type => Logs::ERROR_LOG,
                   :code=>500,
                   :message => msg,
                   :description => error.message,
                   :stacktrace => error.backtrace,
                   :path => app.request.path_info,
                   :ip => app.request.ip,
                   :datetime => Time.new.strftime('%Y-%m-%d_%H:%M:%S')
                  })
    end
    app.slim :error_page, :locals => {:error_code => '500', :error_msg => msg}
  end

  # Writes out a error message in the terminal.
  #
  # @param msg [String] The message to be written.
  # @return [Nil]
  def self.error_msg(msg)
    puts '[Error] ' + msg.to_s
  end
end