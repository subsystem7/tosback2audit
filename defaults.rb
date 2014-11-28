##
# Global Variables
#
#


##
# Path to this code
$analyzer_path = '/Users/asa/Documents/Clients/ISOC/TOSBack2/Analyzer/'

##
# Path to the TOSBack2 instance
$tosback2_data_path = '/Users/asa/Documents/Clients/ISOC/TOSBack2/tosback2-data/'

##
# Path to the live audit output location
$audit_live_base_path = '/Library/WebServer/Documents/isoc_tosback2/audit/'

##
# Path to the staging audit output location
$audit_staging_base_path = '/Library/WebServer/Documents/isoc_tosback2/audit_staging/'

##
# Path to xidel
$xidel = '/Users/asa/Documents/Clients/ISOC/TOSBack2/xidel'

##
# Path to prettify
$prettify = '/Users/asa/Documents/Clients/ISOC/TOSBack2/prettify.py'



##
# Turn on/off debug output
$DEBUG_MODE = true

##
# These variables should not need to be modified

$A_LONG_LONG_TIME_AGO = Time.at(0)

$rules_path = "#{$tosback2_data_path}rules/"
$crawls_path = '../crawls/'

#$audit_host_index_folder_path = "#{$audit_base_path}index/"
def audit_base_path(is_live)
  is_live ?  $audit_live_base_path : $audit_staging_base_path
end

#$audit_host_index_folder_path = "#{$audit_base_path}index/"
def audit_host_index_folder_path(is_live)
  audit_base_path(is_live) + 'index/'
end

#$audit_host_index_snapshots_folder_path = "#{$audit_host_index_folder_path}snapshots/"
def audit_host_index_snapshots_folder_path(is_live)
  audit_host_index_folder_path(is_live) + 'snapshots/'
end

#$audit_changelog_folder_path = "#{$audit_base_path}changelog/"
def audit_changelog_folder_path(is_live)
  audit_base_path(is_live) + 'changelog/'
end

#$audit_changelog_snapshots_folder_path = "#{$audit_changelog_folder_path}snapshots/"
def audit_changelog_snapshots_folder_path(is_live)
  audit_changelog_folder_path(is_live) + 'snapshots/'
end

#$audit_domains_folder_path = "#{$audit_base_path}domains/"
def audit_domains_folder_path(is_live)
  audit_base_path(is_live) + 'domains/'
end
