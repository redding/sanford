module Sanford

  module Host

    def self.included(klass)
      Sanford::Hosts.add(klass)
    end

    # TODO - use this for defaulting a hosts name
    # def registered_name_for(host)
    #   class_name = host.to_s.split('::').last
    #   class_name.gsub(/([a-z\d])([A-Z])/,'\1_\2').downcase
    # end

  end

end
