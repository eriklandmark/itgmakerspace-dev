class ErrorHandler
  def self.e_403(app, msg)
    app.status(403)
    error_msg("(403) -- #{app.request.ip} Resource denied: #{app.request.path_info}")
    if msg.nil?
      app.slim :error_page, :locals => {:error_code => '403', :error_msg => 'Du har inte behörighet till denna sida.'}
    else
      app.slim :error_page, :locals => {:error_code => '403', :error_msg => msg.to_s}
    end
  end

  def self.e_404(app, msg)
    #app.status 404
    error_msg("(404) -- #{app.request.ip} Unknown resource: #{app.request.path_info}")
    if msg.nil?
      app.slim :error_page, :locals => {:error_code => '404', :error_msg => 'Ledsen kompis men kunde inte hitta det du sökte efter..'}
    else
      app.slim :error_page, :locals => {:error_code => '404', :error_msg => msg.to_s}
    end
  end

  def self.e_500(app, msg)
    app.status 500
    error_msg("(500) -- #{app.request.ip} Internal server error: #{app.request.path_info}")
    if msg.nil?
      app.slim :error_page, :locals => {:error_code => '500', :error_msg => 'Ojdå.. Något hände! En rapport har skapats angående felet.'}
    else
      app.slim :error_page, :locals => {:error_code => '500', :error_msg => msg.to_s}
    end
  end

  def self.custom_error(request, code, msg)
    status code
    error_msg("-- #{request.ip}  #{request.path_info} (#{code}) men det uppstod ett fel på serversidan.! ")
    slim :error_page, :locals => {:error_code => '500', :error_msg => msg.to_s}
  end

  def self.error_msg(msg)
    puts '[Error] ' + msg.to_s
  end
end