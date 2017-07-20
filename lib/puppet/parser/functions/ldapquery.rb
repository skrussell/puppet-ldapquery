# Provides a query interface to an LDAP server
#
# @example simple query
#   ldapquery("(objectClass=dnsDomain)", ['dc'])
#
# @example more complex query for ssh public keys
#   ldapquery('(&(objectClass=ldapPublicKey)(sshPublicKey=*)(objectClass=posixAccount))', ['uid', 'sshPublicKey'])
#
require_relative '../../../puppet_x/ldapquery'

Puppet::Functions.create_function(:'ldapquery') do
	confine :feature => :netldap

	local_types do
		type 'Ldapscope = Enum[base, one, sub]'
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
		return PuppetX::LDAPquery.new(filter, attributes, base, scope).results
	end
end
