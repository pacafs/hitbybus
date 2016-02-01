Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github,   '9e3340696d147f69b297', '53ab5b9542aeaf71ce6550ea9d6ea9bc922cf53b', :scope => 'user,user:email,repo'
end

