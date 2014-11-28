require 'nokogiri'
require_relative 'defaults'


#
# This ruby document models the TOSBack2 XML rule file locate in /TOSBack2/rules that is
# used as a basis for pulling down web documents into the archive.
#
# A Rule document sample:
#
# <?xml version="1.0"?>
# <sitename name="twitter.com">
# <docname name="Privacy Policy">
# <url name="http://twitter.com/privacy">
# <norecurse name="arbitrary"/>
# </url>
#  </docname>
# <docname name="Terms of Service">
# <url name="http://twitter.com/tos">
# <norecurse name="arbitrary"/>
# </url>
#  </docname>
# </sitename>
#
#


#
# Used to return the commit ids for a specific archived TOS
#
def get_commits(treepath, repo)
  commits = repo.log('data', treepath)
  commits = nil if commits.empty?
  commits
end



class TOSSiteDocument

  attr_reader :rule_filename, :site_name, :rule_docs, :valid, :site_folder

  def initialize(filename, crawls_path, domains_folder)
    @rule_filename = filename
    #@domains_folder = domains_folder  # $audit_domains_folder_path
    @valid = true
    File.open(@rule_filename, 'r') { |rule_file|
      xml = Nokogiri::XML(rule_file)
      # puts(xml.to_s)

      # only one site
      @site_name = xml.at_xpath('//sitename/@name')
      @site_folder = "#{domains_folder}#{@site_name}/"
      @valid &= check_or_create_dir("#{@site_folder}", false)

      log("@site_name: #{@site_name}")
      #log("@valid: #{@valid}")

      # one or more docs
      @rule_docs = Array.new
      doc_elements = xml.xpath('//sitename/docname')
      doc_list = ''
      doc_elements.each { |doc_element|
        doc = TOSRuleDocument.new(doc_element, self, "#{@site_folder}", "#{crawls_path}#{@site_name}")
        @rule_docs.push(doc)
        doc_list += "#{doc.doc_folder_name}\n"
      }

      if($DEBUG_MODE) then
        log("rule doc count: #{@rule_docs.length}")

        (0..@rule_docs.length-1).each { |i|
          log("#{@rule_docs[i].doc_folder_name}")
        }
      end


      # meta.xml - which lists the content folders and some meta data about them
      #
      # <?xml version="1.0"?>
      # <Policies>
      #   <Policy
      #     type="tos"
      #     folder="basetermsofservice"
      #     name="Base Terms Of Service"
      #     url="http://base.google.com/support/bin/answer.py?hl=en&amp;answer=62594"
      #     latest="1275856465"
      #     />
      # </Policies>
      #
      if !File.exists?("#{@site_folder}index.xml") then
        File.open("#{@site_folder}index.xml", 'w') { |index|
          index_xml = Nokogiri::XML::Builder.new do |xml|
            xml.Policies {
              @rule_docs.each { |doc|
                xml.Policy(:type => doc.type, :folder => doc.doc_folder_name, :name => doc.name, :url => doc.url_name, :latest => $A_LONG_LONG_TIME_AGO.to_i.to_s)
              }
            }
          end
          index.write(index_xml.to_xml)
        }
      else
        # In the case where more than one rule file contains the same site, the
        # Policy may have not yet been added to the index.xml file - this remedies
        # that situation.

        # Open the index.xml file
        xml = Nokogiri::XML(File.read("#{@site_folder}index.xml"))

        @rule_docs.each { |doc|
          # find the policy listing and update the latest attribute
          test = xml.at_xpath("//Policy[@name='#{doc.name}']")
          if(test.nil?) then
            policy = Nokogiri::XML::Node.new 'Policy', xml
            policy['type'] = doc.type
            policy['folder'] =doc.doc_folder_name
            policy['name'] = doc.name
            policy['url'] = doc.url_name
            policy['latest'] = $A_LONG_LONG_TIME_AGO.to_i.to_s
            policies = xml.at_xpath('/Policies')
            policies.add_child(policy)
            File.write!("#{@site_folder}index.xml", xml)
          end
        }
      end

      File.write!("#{@site_folder}index", doc_list)
    }

  end

  # This method makes sure that all of the folders and index files exist and are set up properly
  def check_heirarchy





  end


end




class TOSRuleDocument

  attr_reader :name, :full_path, :p_path, :p_name, :repo_tree_path, :doc_folder_name, :url_name, :valid, :latest_update

  def initialize(doc_element, site_doc, audit_path, site_crawls_path)
    @site_doc = site_doc
    @valid = true
    @latest_update = nil
    #puts(doc_element.to_s)

    @name = doc_element.at_xpath('@name')
    @doc_folder_name = @name.to_s.gsub(/ /, '-')

    # a custom path may be specified which is used to pull the policy snapshots
    # from the repo. The rule file of the policy will contain a gitpath element
    # as shown below, as CDATA
    # <sitename ...>
    #   <docname ...>
    #     <gitpath><![CDATA[crawls/www.amazon.com/Kindle-License-Agreement-and-Terms-of-Use/raw/www.amazon.com/gp/help/customer/display.html/<.html]]></gitpath>

    custom_repo_tree_path = nil
    tmp = doc_element.at_xpath('gitpath')
    if(!tmp.nil? && tmp.element?)
      custom_repo_tree_path = tmp.child.content
    end

    # clean up the URL
    @url_name = doc_element.at_xpath('url/@name').to_s.sub(/http:\/\//, '')
    @url_name = @url_name.to_s.sub(/https:\/\//, '')

    @content_folder = "#{audit_path}#{@doc_folder_name}/"
    @snapshots_folder = "#{@content_folder}snapshots/"
    # content folder
    @valid &= check_or_create_dir(@content_folder, false)

    # content folder / snapshots    - historical and current snapshots
    @valid &= check_or_create_dir(@snapshots_folder, false)


    #puts 'site: ' + @site_name + ' doc: ' + @doc_folder_name + ' url: ' + @url_name
    #puts "RULE FILE " + rule_file.inspect

    # No custom path specified, process as normal
    if custom_repo_tree_path.nil? then
      log('custom_repo_tree_path is nil')

      @full_path = site_crawls_path + '/' + @doc_folder_name + '/raw/' + @url_name

      log(@full_path)


      @p_path = @full_path.sub(/\/[^\/]+$/, '/')
      @p_name = @full_path.sub(/.*\//, '')

      # &#x26;
      # need to only replace the appearance of "#" and following characters if it is an anchor, not if it is a special character code.
      #@p_name = @p_name.sub(/#.*/,'')
      # if it ends in "/" then need to append "index.html"
      #
      # easy to see the the problem ones by:
      # cd /Users/asa/Documents/Clients/ISOC/TOSBack2/tosback2-data/rules_all
      # grep "#" *.xml
      #
      #@p_name = @p_name.sub(/\&\#x26\;/,'&')

      # fixes privacy-policy#sharing-information.html, e.g. - zoosk.com
      @p_name = @p_name.sub(/#.*/,'')

      # fixes empty endings such as xfinity.comcast.net which start as being #full and end empty
      @p_name = @p_name + 'index.html' if @p_name.empty?

      @p_name = @p_name + '.html' if @p_name.match(/.*\.html$/).nil? && @p_name.match(/.*\.htm$/).nil?

      @repo_tree_path = "#{@p_path}#{@p_name}".sub(/^.../, '')

    # Rule file contains a custom git path
    else
      @repo_tree_path = custom_repo_tree_path
    end

    log(@repo_tree_path)

  end


  def process(repository, redo_all)
    if(@valid) then

      #commit_array = get_commits('crawls/amctheaters.com/Privacy-Policy/raw/www.amctheatres.com/Privacypolicy/index.html?WT.mc_id=nh_about.html', repository)
      commit_array = get_commits(@repo_tree_path, repository) #, current_commit)
      log(commit_array!=nil ? commit_array.join(' ') : 'no commits')

      if(commit_array) then

        latestref_path = "#{@content_folder}latestref"

        latestref_value = $A_LONG_LONG_TIME_AGO

        # Get the latestref file, assuming it exists
        # Check for the latest run time
        if !redo_all && File.exists?(latestref_path)
          latestref_file = File.open(latestref_path)
          latestref_value = time_from_seconds(latestref_file.gets)
          if latestref_value.nil? then
            latestref_value = $A_LONG_LONG_TIME_AGO
            log('invalid latestref_value') if $DEBUG_MODE
          end
          latestref_file.close
        end

        latest_commit = nil

        processing_rules = nil

        # runs through the commits for the TOS file and outputs any committed files that
        # have a greater date than the run_as_of variable
        commit_array.reverse_each { |commit|
          if latestref_value < commit.date.to_time && !File.exists?("#{@snapshots_folder}#{commit.date.to_i.to_s}.ignore") then

            data = subtree_data(commit, @repo_tree_path)

            if(!data.nil?) then

              File.write!("#{@snapshots_folder}#{commit.date.to_i.to_s}.raw", data)

              # At this point, any custom extraction/cleanup of the raw file need to be executed before
              # beautiful soup is used to prettify the HTML
              #
              # 1334505419.processingrules.xml :
              #
              # <?xml version="1.0"?>
              # <ProcessingRule>
              #   <Command><![CDATA[<div id="footerPageContent">{.}</div>]]></Command>
              # </ProcessingRule>
              #
              if File.exists?("#{@snapshots_folder}#{commit.date.to_i.to_s}.processingrules.xml")
                processing_rules = Nokogiri::XML(File.read("#{@snapshots_folder}#{commit.date.to_i.to_s}.processingrules.xml"))
              end

              cmd = "cat #{@snapshots_folder}#{commit.date.to_i.to_s}.raw"

              if(!processing_rules.nil?) then
                command_element = processing_rules.at_xpath('/ProcessingRule/Command')
                cmd = "#{$xidel} #{@snapshots_folder}#{commit.date.to_i.to_s}.raw -e '#{command_element.text}' --output-format html"
              end

              cmd << " | python #{$prettify}"

              ## log("#{cmd}")

              pretty = %x[ #{cmd} ]
              File.write!("#{@snapshots_folder}#{commit.date.to_i.to_s}", pretty)

              ## log("Writing #{@snapshots_folder}#{commit.date.to_i.to_s}") if $DEBUG_MODE
              @latest_update = commit.date.to_i.to_s
              latest_commit = commit
              @updated = true
            else
              log("Data from commit #{commit.date.to_i.to_s} of site  #{@site_doc.site_name} #{@name} was nil.")
            end
          end
        }

        if !latest_commit.nil? then

            # LATEST RAW HTML
            FileUtils.copy("#{@snapshots_folder}#{latest_commit.date.to_i.to_s}.raw", "#{@content_folder}latest.raw")

            # LATEST PRETTY HTML
            FileUtils.copy("#{@snapshots_folder}#{latest_commit.date.to_i.to_s}", "#{@content_folder}latest")

            # LATEST REFERENCE FILE
            # content folder / latestref    - reference to the file in snapshots that is the latest one
            File.write!(latestref_path, "#{latest_commit.date.to_i.to_s}")

            # Open the index.xml file, and set the latest version attribute
            xml = Nokogiri::XML(File.read("#{@site_doc.site_folder}index.xml"))

            # find the policy listing and update the latest attribute
            policy_element = xml.at_xpath("//Policy[@name='#{@name}']")
            policy_element['latest'] = @latest_update

            # write the file out
            File.write!("#{@site_doc.site_folder}index.xml", xml)

        end
      else
        log("No commit array for #{@site_doc.site_name} #{@name}")
      end
    end
  end

  def type
    type = 'unknown'
    _name = @name.to_s.downcase
    if(_name.include? 'terms') then
      type = 'tos'
    elsif(_name.include? 'privacy') then
      type = 'privacy'
    elsif(_name.include? 'policy') then
      type = 'policy'
    end
    type
  end

  def checkpath?
    Dir.exists?(@p_path)
  end

  def checkfile?
    File.exists?(@full_path)
  end

  private

  #
  # This method returns the data from a specific commit associated with the
  # object we are looking for.
  #
  def subtree_data(commit, sub_obj)
    tree_sub_object = commit.tree / sub_obj
    data = nil

    #
    if(tree_sub_object.nil?) then
      tree_sub_object = commit.tree / sub_obj.to_s.sub(/\/\//, "\/")
    end

    if tree_sub_object.nil?
      log("no data for commit #{commit.date.to_i.to_s} for #{sub_obj}")
    else
      data = tree_sub_object.data
    end

    data
  end

end