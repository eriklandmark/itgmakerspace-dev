module User_Authentication
  def logged_in?
    return false if session[:user_id].nil? else true
  end

  def has_auth_level?(level)
    if logged_in? && !session[:permission_level].nil?
      if session[:permission_level].to_i >= level.to_i
        true
      else
        false
      end
    else
      false
    end
  end
end
