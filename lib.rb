def get_month_num_from_name(month:)
  %w(January February March April May June July August September October November December).index(month) + 1
end

def get_inv_img_ext
  hash = {}
  Dir.foreach("public/product_images").each do |file|
    if file.include?("_")
      names = file.split(".")
      hash[names[0]] = names[1]
    end
  end
  hash
end

def get_inv_img_ext_from_id(id)
  Dir.foreach("public/product_images").each do |file|
    return file.split(".")[1].to_s if file.include?(id.to_s)
  end
end

def get_prof_img_ext_from_id(id)
  Dir.foreach("public/profile_images").each do |file|
    return file.split(".")[1].to_s if file.include?(id.to_s)
  end
end

def valid_json?(json)
  !!JSON.parse(json)
rescue JSON::ParserError => _
  false
end