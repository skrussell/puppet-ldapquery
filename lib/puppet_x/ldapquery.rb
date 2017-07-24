# Class: PuppetX::LDAPquery
#

module PuppetX
  class LDAPquery
    attr_reader :content

    def initialize(
      filter,
      attributes = [],
      base = Puppet[:ldapbase],
      scope = 'sub'
    )
      @filter = filter
      @attributes = attributes
      @base = base

      return unless scope

      if scope == 'sub'
        @scope = Net::LDAP::SearchScope_WholeSubtree
      elsif scope == 'base'
        @scope = Net::LDAP::SearchScope_BaseObject
      elsif scope == 'single'
        @scope = Net::LDAP::SearchScope_SingleLevel
      else
        raise Puppet::ParseError, 'Received param "scope" not one of ["sub","base","single"]'
      end
    end

    def ldap_config(host)
      # Load the configuration variables from Puppet
      required_vars = [
        :ldapport
      ]

      required_vars.each do |r|
        unless Puppet[r]
          raise Puppet::ParseError, "Missing required setting '#{r}' in puppet.conf"
        end
      end

      port = Puppet[:ldapport]

      if Puppet[:ldapuser] && Puppet[:ldappassword]
        user     = Puppet[:ldapuser]
        password = Puppet[:ldappassword]
      end

      conf = {
        host: host,
        port: port
      }

      if (user != '') && (password != '')
        conf[:auth] = {
          method: :simple,
          username: user,
          password: password
        }
      end

      tls = Puppet[:ldaptls]
      if tls
        tls_method = Puppet[:ldaptlsmethod]
        if tls_method
            unless tls_method == 'start_tls' or tls_method == 'simple_tls'
                raise Puppet::ParseError, "LDAP setting 'ldaptlsmethod' must be one of 'start_tls' or 'simple_tls'"
            end
            if Puppet[:ldaptlsmethod] == 'start_tls'
                method = :start_tls
            else
                method = :simple_tls
            end
        else
            if port == 389
                method = :start_tls
            elsif port == 636
                method = :simple_tls
            end
        end
        ca_file = "#{Puppet[:confdir]}/ldap_ca.pem"
        if (File.file?(ca_file) || File.file?(ca_file))
            conf[:encryption] = {
              method: method,
              tls_options: { ca_file: ca_file }
            }
        else
            raise Puppet::ParseError, "'#{ca_file}' does not exist!"
        end
      end

      conf
    end

    def entries
        # Query the LDAP server for attributes using the filter
        #
        # Returns: An array of Net::LDAP::Entry objects
        search_args = {
          base: @base,
          attributes: @attributes,
          scope: @scope,
          time: 10
        }

        if @filter && !@filter.empty?
            ldapfilter = Net::LDAP::Filter.construct(@filter)
            search_args[:filter] = ldapfilter
        end

        entries = []

        begin
            start_time = Time.now
            @ldap.search(search_args) do |entry|
                entries << entry
            end
            end_time = Time.now
            time_delta = format('%.3f', end_time - start_time)

            Puppet.debug("ldapquery(): Searching #{@base} for #{@attributes} using #{@filter} took #{time_delta} seconds and returned #{entries.length} results")
        rescue Net::LDAP::LdapError => e
            Puppet.debug("There was an error searching LDAP #{e.message}")
        end
        return entries
    end

    def parse_entries
      data = []
      entries.each do |entry|
        entry_data = {}
        entry.each do |attribute, values|
          attr = attribute.to_s
          value_data = []
          Array(values).flatten.each do |v|
            value_data << v.chomp
          end
          entry_data[attr] = value_data
        end
        data << entry_data
      end
      Puppet.debug(data)
      data
    end

    def connect
        connect_success = false
        unless Puppet[:ldapserver]
            raise Puppet::ParseError, "Missing required setting 'ldapserver' in puppet.conf"
        end
        servers = Puppet[:ldapserver]
        hosts = []
        if servers.count(",") > 0
            hosts = servers.split(",")
        else
            hosts.push servers
        end

        for host in hosts
            Puppet.debug("Attempting LDAP connection to server: #{host}")
            conf = ldap_config(host)
            ldap = Net::LDAP.new(conf)
            begin
                if ldap.bind
                    connect_success = true
                    @ldap = ldap
                    break
                else
                    Puppet.info "Connection result to server #{host}: (#{ldap.get_operation_result.code}) #{ldap.get_operation_result.message}"
                end
#            rescue Net::LDAP::Error => e
            rescue => e
                Puppet.info("An error occured when trying to connect to LDAP host: #{host}, Class: #{e.class}, #{e.message}")
            end
        end
        connect_success
    end

    def results
        parse_entries
    end
  end
end
