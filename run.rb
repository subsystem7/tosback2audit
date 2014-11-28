require_relative 'analyzer'

# run.rb
#
#
def run



  live = true
  redo_all = false

  # running a single
  a = Analyzer.new('addictinggames.com.xml', live, redo_all)
  #a = Analyzer.new('app.net.xml', live, redo_all)

  # run all



  # amazon_Kindle_License_Agreement_and_Terms_of_Use.xml :
  #
  # <sitename name="www.amazon.com">
  #   <docname name="Kindle License Agreement and Terms of Use">
  #     <url name="http://www.amazon.com/gp/help/customer/display.html/?&amp;nodeId=200506200">
  #       <norecurse name="arbitrary"/>
  #     </url>
  #     <gitpath><![CDATA[crawls/www.amazon.com/Kindle-License-Agreement-and-Terms-of-Use/raw/www.amazon.com/gp/help/customer/display.html/<.html]]></gitpath>
  #   </docname>
  # </sitename>
  #
  #a = Analyzer.new('amazon_Kindle_License_Agreement_and_Terms_of_Use.xml', live, redo_all)

  #a = Analyzer.new('amctheaters.com.xml', live, redo_all)

end

run

exit
