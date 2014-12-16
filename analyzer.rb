require 'grit'
require 'fileutils'
require 'open-uri'
require 'nokogiri'
require_relative 'tos_site_document'
require_relative 'util_functions'
require_relative 'defaults'

##
# Analyzes domain(s) stored in a TOSBack2 git repository using the same rules that the TOSBack2
# crawler uses.
#
# ==== Examples
#
# Run a single rule, writing results to the live server, not overwriting existing files associated with pre-analyzed commits
#   Analyzer.new('app.net.xml', true, false)
#
# Run all of the rules, writing to the live server, overwriting existing files associated with pre-analyzed commits
#   Analyzer.new(nil, true, true)

class Analyzer

  ##
  # Runs the analyzer, updating all audit system bookkeeping.
  #
  # ==== Attributes
  #
  # * +rule_file_to_process+ - specifies the rule file that should be processed. If this is 'nil' then all rules are processed.
  # * +is_live+ - if true, the live audit folder is used for output, otherwise, the staging folder is used.
  # * +redo_all+ - if true, the analyzer reprocesses previously processed commits
  #

  def initialize(rule_file_to_process, is_live, redo_all)

    @is_live = if nil == is_live
                 false
               else
                 is_live
               end

    @redo_all = if nil == redo_all
                  false
                else
                  redo_all
                end

    #sanity checks
    check_or_create_dir(audit_base_path(@is_live), true)
    check_or_create_dir(audit_changelog_folder_path(@is_live), true)
    check_or_create_dir(audit_changelog_snapshots_folder_path(@is_live), true)
    check_or_create_dir(audit_domains_folder_path(@is_live), true)
    check_or_create_dir(audit_host_index_folder_path(@is_live), true)
    check_or_create_dir(audit_host_index_snapshots_folder_path(@is_live), true)

    # Open the repository
    @repo = Grit::Repo.new($tosback2_data_path)  #'../tosback2-data')
    current_commit = @repo.head.commit
    log('Latest Commit Date: ' + current_commit.committed_date.asctime + '\n' ) if $DEBUG_MODE


    #log('test2 ' + current_commit.committed_date.t_audit_file_name.t_time_f_audit_file_name.asctime+'\n' )

    # create the latestcheck file at the root of the API directory
    latestcheckfile = File.new("#{audit_base_path(@is_live)}latestcheck", 'w')
    latestcheckfile.write(current_commit.committed_date.t_audit_file_name)
    latestcheckfile.close

    # Check for the latest run time
    if File.exists?("#{audit_base_path(@is_live)}latestcheck")
      latestcheckfile = File.open("#{audit_base_path(@is_live)}latestcheck")
      time = latestcheckfile.gets.t_time_f_audit_file_name #time_from_seconds(latestcheckfile.gets)
      log( (nil!=time ? time.asctime : 'no time') )
      latestcheckfile.close
    end


    Dir.chdir($rules_path) do

      # open a temporary host index file, which is renamed as the latest index file if anything has changed.
      @index_file = File.open(audit_host_index_snapshots_folder_path(@is_live)+'_tmp', 'w')
      @updated_snapshots = Array.new

      if nil == rule_file_to_process then
        # loop through each xml rule file, creating a TOSSiteDocument which
        # will contain one or more TOSRuleDocument, which represents a single
        # policy stored in the repository.
        Dir['*.xml'].each { |rule_file_name|
          process_rule_file(rule_file_name, @redo_all)
        } # each xml rule file
      else
        process_rule_file(rule_file_to_process, @redo_all)
      end

      # close the temporary index file
      @index_file.close

      # get the current time which will be used to update varous logs and indices
      now = Time.new

      # update the change log
      if @updated_snapshots.count > 0 then
        File.write!("#{audit_changelog_snapshots_folder_path(@is_live)}#{now.t_audit_file_name}", @updated_snapshots.join("\n"))
        File.write!("#{audit_changelog_folder_path(@is_live)}latest", "#{now.t_audit_file_name}")
      end

      # do the book keeping around the index snapshots
      if(File.exists?("#{audit_host_index_folder_path(@is_live)}latestref")) then
        # Here we test whether anything has changed and if it has, we write a new snapshot file
        previous_latest = get_time_from_file_type_latest("#{audit_host_index_folder_path(@is_live)}latestref")
        if(nil != previous_latest && FileUtils.compare_file("#{audit_host_index_snapshots_folder_path(@is_live)}_tmp", "#{audit_host_index_snapshots_folder_path(@is_live)}#{previous_latest.t_audit_file_name}")) then
          log('they are the same') if $DEBUG_MODE
          # unlink the temporary file
          File.delete("#{audit_host_index_snapshots_folder_path(@is_live)}_tmp")
        else
          log('they are different') if $DEBUG_MODE

          # create a new 'latestref' file and rename the snapshot
          latestindexfile = File.new("#{audit_host_index_folder_path(@is_live)}latestref", 'w')
          latestindexfile.write(now.t_audit_file_name)
          latestindexfile.close

          # move the index_file to the latest
          File.rename("#{audit_host_index_snapshots_folder_path(@is_live)}_tmp", "#{audit_host_index_snapshots_folder_path(@is_live)}#{now.t_audit_file_name}")
          FileUtils.copy("#{audit_host_index_snapshots_folder_path(@is_live)}#{now.t_audit_file_name}", "#{audit_host_index_folder_path(@is_live)}latest")
        end
      else
        # This is the case where there is no "latest" file.  The very first snapshot and latest are created
        latestindexfile = File.new("#{audit_host_index_folder_path(@is_live)}latestref", 'w')
        latestindexfile.write(now.t_audit_file_name)
        latestindexfile.close

        # move the index_file to the latest
        File.rename("#{audit_host_index_snapshots_folder_path(@is_live)}_tmp", "#{audit_host_index_snapshots_folder_path(@is_live)}#{now.t_audit_file_name}")
        FileUtils.copy("#{audit_host_index_snapshots_folder_path(@is_live)}#{now.t_audit_file_name}", "#{audit_host_index_folder_path(@is_live)}latest")
      end

    end # Dir.chdir

  end

  ##
  # Processes a single rule file.
  #
  # ==== Attributes
  #
  # * +rule_file_name+ - specifies the rule file that should be processed
  # * +redo_all+ - if true, reprocesses previously processed commits

  def process_rule_file(rule_file_name, redo_all)

    site_doc = TOSSiteDocument.new(rule_file_name, $crawls_path, audit_domains_folder_path(@is_live))

    if(site_doc.valid) then

      log("#{site_doc.site_name}")  if $DEBUG_MODE

      # add the current site to the temporary host index file
      @index_file.write("#{site_doc.site_name}\n")

      # create the output directory if not already there
      #if(!Dir.exists?("#{$output_path}#{site_doc.site_name}")) then
      #  Dir.mkdir("#{$output_path}#{site_doc.site_name}")
      #end

      # loop through every document associated with a site and process the
      site_doc.rule_docs.each { |rule_doc|
        rule_doc.process(@repo, redo_all)
        # domains/[name_of_site]/[name_of_document]/snapshots/[encoded_date_of_latest_update]
        @updated_snapshots.push("domains/#{site_doc.site_name}/#{rule_doc.doc_folder_name}/snapshots/#{rule_doc.latest_update}") if !rule_doc.latest_update.nil?
      }

    else
      log("#{rule_file_name} is invalid.")
    end

  end

end


