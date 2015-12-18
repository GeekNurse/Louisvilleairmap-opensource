TODAY = Date.today.strftime("%Y%m%d")
YESTERDAY = Date.yesterday.strftime("%Y%m%d")
YESTER2 = (Date.today - 1).strftime("%Y%m%d")
YESTER3 = (Date.today - 1).strftime("%Y%m%d")
HOURS = (0..24).map{|n| format('%02d', n)}

def fix_encoding(string)
  string.to_s.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '???').gsub(";","-").gsub("&","and")
end
