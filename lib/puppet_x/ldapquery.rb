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

      tls = Puppet[:ldaptls]
      ca_file = "#{Puppet[:confdir]}/ldap_ca.pem"

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

      if tls
        conf[:encryption] = {
          method: :simple_tls,
          tls_options: { ca_file: ca_file }
        }
      end

      conf
    end

    def entries
      # Query the LDAP server for attributes using the filter
      #
      # Returns: An array of Net::LDAP::Entry objects
      unless Puppet[:ldapserver]
        raise Puppet::ParseError, "Missing required setting 'ldapserver' in puppet.conf"
      end

      servers = Puppet[:ldapserver]
      hosts = Array.new
      if servers.count(",") > 0
        hosts = servers.split(",")
      else
        hosts.push servers
      end

      $connect_success = false
      while !$connect_success
        for host in hosts
          Puppet.debug("Attempting LDAP connection to server: #{host}")
          conf = ldap_config(host)

          start_time = Time.now
          ldap = Net::LDAP.new(conf)
          if ldap.bind
            $connect_success = true

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
              ldap.search(search_args) do |entry|
                entries << entry
              end
              end_time = Time.now
              time_delta = format('%.3f', end_time - start_time)

              Puppet.debug("ldapquery(): Searching #{@base} for #{@attributes} using #{@filter} took #{time_delta} seconds and returned #{entries.length} results")
              return entries
            rescue Net::LDAP::LdapError => e
              Puppet.debug("There was an error searching LDAP #{e.message}")
              Puppet.debug('Returning false')
              return false
            end
          else
            p ldap.get_operation_result
            Puppet.debug("Connection result to server #{host}: (#{ldap.get_operation_result.code}) #{ldap.get_operation_result.message}")
          end
        end
      end
      if !$connect_success
        Puppet.debug("There was an error connecting to LDAP")
        return false
      end
    end

    def parse_entries
      results = Hash.new
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
      results['data'] = data
      results
    end

    def results
      parse_entries
    end
  end
end
