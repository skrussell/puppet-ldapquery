# Provides a query interface to an LDAP server
#
# @example simple query
#   ldapquery("(objectClass=dnsDomain)", ['dc'])
#
# @example more complex query for ssh public keys
#   ldapquery('(&(objectClass=ldapPublicKey)(sshPublicKey=*)(objectClass=posixAccount))', ['uid', 'sshPublicKey'])
#
Puppet::Functions.create_function(:ldapquery) do
	require_relative '../../puppet_x/ldapquery'

	local_types do
		type 'Ldapscope = Enum[base,one,sub]'
	end

	# Runs a query against LDAP
	# @param [String] filter A standard (rfc4515) LDAP search filter.
	# @param [Array[String]] attributes A list of attributes to return from the search.
	# @param [String] base The LDAP base DN to search (defaults to puppet config value of 'ldapbase').
	# @param [String] scope The scope for the LDAP search (base/one/sub).
	# @return [Hash]
	# @example
	#	ldapquery('(objectClass=posixAccount)', [ 'uid' ])
	dispatch :doquery do
		required_param 'String', :filter
		optional_param 'Array[String]', :attributes
		optional_param 'String', :base
		optional_param 'Ldapscope', :scope
		return_type 'Hash'
	end
	def doquery(filter, attributes = [], base = Puppet[:ldapbase], scope = 'sub')
		result = Hash.new
		result['success'] = false
		begin
			require 'net/ldap'
			query = PuppetX::LDAPquery.new(filter, attributes, base, scope)
			if query.connect
				result['status'] = 'connected'
				begin
					data = query.results
					result['data'] = data
					result['success'] = true
				rescue => e
					Puppet.notice("An error occured whilst fetching the LDAP data: (#{e.class}) '#{e.message}'")
				end
			else
				result['status'] = 'connection_error'
			end
		rescue LoadError => e
			raise unless e.message =~ /net\/ldap/
			Puppet.notice('Missing net/ldap gem required for ldapquery() function')
			result['status'] = 'no_netldap_module'
		end
		return result
	end
end
