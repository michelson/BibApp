# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  require 'config/personalize.rb'
  require 'htmlentities' if defined? HTMLEntities

  def ajax_pen_name_checkbox_toggle(name_string, person, selected, reload = false)
    if selected
      pen_name = PenName.find_by_person_id_and_name_string_id(person.id, name_string.id)
      js = remote_function(:url => pen_name_url(pen_name, :reload => reload, :person_id => person.id,
                                                :name_string_id => name_string.id),
                           :method => :delete)
    else
      js = remote_function(:url => pen_names_url(:person_id => person.id, :reload => reload,
                                                 :name_string_id => name_string.id),
                           :method => :post)
    end
    check_box_tag("name_string_#{name_string.id}_toggle", 1, selected, {:onclick => js})
  end

  def letter_link_for(letters, letter, current, path)
    if path.nil?
      if current == true
        content_tag(:li, (letters.index(letter) ? link_to(letter, {:page=> letter}, :class => "some") : content_tag(:a, letter, :class => 'none')), :class => "current")
      else
        content_tag :li, (letters.index(letter) ? link_to(letter, {:page=> letter}, :class => "some") : content_tag(:a, letter, :class => 'none'))
      end
    else
      if current == true
        content_tag(:li, (letters.index(letter) ? link_to(letter, "#{path[:path]}?page=#{letter}", :class => "some") : content_tag(:a, letter, :class => 'none')), :class => "current")
      else
        content_tag :li, (letters.index(letter) ? link_to(letter, "#{path[:path]}?page=#{letter}", :class => "some") : content_tag(:a, letter, :class => 'none'))
      end
    end
  end

  def link_to_related_works(work)
    #link_to "Related Works", search_url(:q => "id:#{work-solr_id}", :qt  => "mlt")
    "Related Works"
  end

  def link_to_download_from_archive(work)
    #link_to "Download from #{$REPOSITORY_NAME}"
    "Download from #{$REPOSITORY_NAME}"
  end

  def link_to_authors(work)
    links = Array.new

    if work['authors_data'] != nil
      work['authors_data'].first(5).each do |au|
        name, id = NameString.parse_solr_data(au)
        links << link_to(h("#{name.gsub(",", ", ")}"), name_string_path(id), {:class => "name_string"})
      end

      if work['authors_data'].size > 5
        links << link_to("more...", work_path(work['pk_i']))
      end
    end

    links.join(", ").html_safe
  end

  def link_to_editors(work)
    if work['editors_data'] != nil
      # If no authors, editors go first
      str = work['authors_data'] ? "In " : ''
      links = Array.new

      work['editors_data'].first(5).each do |ed|
        name, id = NameString.parse_solr_data(ed)
        links << link_to(h("#{name.gsub(",", ", ")}"), name_string_path(id), {:class => "name_string"})
      end

      if work['editors_data'].size > 5
        links << link_to("more...", work_path(work['pk_i']))
      end

      str += links.join(", ")
      str += " (Eds.), "
      str
    end
  end

  def link_to_work_publication(work)
    if work['publication_data'].blank?
      "Unknown"
    else
      pub_name, pub_id = Publication.parse_solr_data(work['publication_data'])
      link_to("#{pub_name}", publication_path(pub_id), {:class => "source"})
    end
  end

  def link_to_work_publisher(work)
    if work['publisher_data'].blank?
      "Unknown"
    else
      pub_name, pub_id = Publisher.parse_solr_data(work['publisher_data'])
      link_to("#{pub_name}", publisher_path(pub_id), {:class => "source"})
    end
  end

  #Generate a "Find It!" OpenURL link, 
  # based on Work information as received from Solr
  def link_to_findit(work)

    #Get our OpenURL information
    link_text, base_url, suffix = find_openurl_info

    suffix =coin(work)

    # Prepare link
    link_to link_text, "#{base_url}?#{suffix}"
  end

  def work_details(work)
    str = ""
    str += link_to "#{work.publication.authority.name}", publication_path(work.publication.authority.id) if work.publication.authority != nil && work.publication.authority.name != "Unknown"
    str += " &#149; " if work.publication.authority != nil && work.publication.authority.name != "Unknown"
    str += "#{work.publication_date.year} " if work.publication_date != nil
    str += " #{work.volume}" if work.volume != nil
    str += "(#{work.issue}), " if work.issue != nil && !work.issue.empty?
    str += " pgs."
    str += " #{work.start_page}-" if work.start_page != nil
    str += "#{work.end_page}." if work.end_page != nil
    str
  end

  def link_to_google_book(work)
    if !work.publication.nil? and !work.publication.isbns.blank?
      capture_haml :div, {:class => "right"} do
        haml_tag :span, {:title => "ISBN"}
        work.publication.isbns.first[:name]
        haml_tag :span, {:title => "ISBN:#{work.publication.isbns.first[:name]}", :class =>"gbs-thumbnail gbs-link-to-preview gbs-link"}
      end
    elsif !work.publication.nil? and !work.publication.issn_isbn.blank?
      capture_haml :div, {:class => "right"} do
        haml_tag :span, {:title => "ISBN"}
        work.publication.issn_isbn
        haml_tag :span, {:title => "ISBN:#{work.publication.issn_isbn.gsub(" ", "")}", :class =>"gbs-thumbnail gbs-link-to-preview gbs-link"}
      end
    else
      # Nothing
    end
  end

  def coin(work)
    # @TODO - improve - probably have subklass.to_coin methods for each.
    # Genre differences: journal/article = atitle ; book/proceeding = title

    coin = "ctx_ver=Z39.88-2004" # OpenURL 1.0

    # We want AR objects!
    if work.class == Hash
      begin
        work = Work.find(work["pk_i"]).include(:authors)
      rescue
        return coin
      end
    end


    if work.open_url_kevs.present?
      work.open_url_kevs.each do |kev, value| # Work Subklass Kevs
        coin += value
      end
    end

    work.authors.each do |au| # Authors
      coin += "&rft.au=#{au[:name]}"
    end

    coin
  end

  def add_filter(params, facet, value, count)
    filter = Hash.new
    if params[:fq]
      filter[:fq] = params[:fq].collect
    else
      filter[:fq] = []
    end

    filter[:fq] << "#{facet}:\"#{value}\""
    filter[:fq].uniq!

    link_to "#{value} (#{count})", params.merge(filter)
  end

  def remove_filter(params, facet)
    filter = Hash.new
    if params[:fq]
      filter[:fq] = params[:fq].collect
      filter[:fq].delete(facet)
      filter[:fq].uniq!

      #Split filter into field name and display value (they are separated by a colon)
      field_name, display_value = facet.split(':')
      link_to "#{display_value}", params.merge(filter)
    end
  end

  #Encodes UTF-8 data such that it is valid in HTML
  def encode_for_html(data)
    code = HTMLEntities.new
    code.encode(data, :decimal)
  end

  #Encodes UTF-8 data such that it is valid in XML
  def encode_for_xml(data)
    code = HTMLEntities.new
    code.encode(data, :basic)
  end

  #Determines the pretty name of a particular Work Status
  def work_state_name(work_state_id)
    #Load Work States hash from personalize.rb
    $WORK_STATUS[work_state_id]
  end

  #Determines the pretty name of a particular Work Archival Status
  def work_archive_state_name(work_archive_state_id)
    #Load Work States hash from personalize.rb
    $WORK_ARCHIVE_STATUS[work_archive_state_id]
  end

  #Finds the Error message for a *specific field* in a Form
  # This is useful to display the error messages next to the
  # appropriate field in a form.
  # This displays a <div> with the error message right after the field
  # Borrowed from: http://www.sciwerks.com/blog/category/ruby-on-rails/page/2/
  def error_for(object, method = nil, options={})
    if method
      err = instance_variable_get("@#{object}").errors[method].to_sentence rescue instance_variable_get("@#{object}").errors[method]
    else
      err = @errors["#{object}"] rescue nil
    end
    options.merge!(:class=>'fieldWithErrors', :id=>"#{[object, method].compact.join('_')}-error", :style=> (err ? "#{options[:style]}" : "#{options[:style]};display: none;"))
    content_tag("p", err || "", options)
  end

  #create a hash for Haml that gives id => current if the controller matches the argument
  def give_current_id_if_equal(name1, name2)
    name1 == name2 ? {:id => 'current'} : {}
  end

  def give_current_class_if_equal(name1, name2)
    name1 == name2 ? {:class => 'current'} : {}
  end

  private

  #Find information necessary to build our OpenURL query
  #  In particular:
  #    OpenURL link text, base url, and query suffixes
  def find_openurl_info
    # Set the canonical resolver variables (from personalize.rb)
    link_text = $WORK_LINK_TEXT
    base_url = $WORK_BASE_URL
    suffix = $WORK_SUFFIX
=begin
    #If we've already found this info for
    # the current session, return it immediately
    if session[:openurl_info]
      link_text = session[:openurl_link_text] if session[:openurl_link_text]
      base_url = session[:openurl_base_url] if session[:openurl_base_url]
    else 
      # Obtain the client IP Addess
      ip = request.env["HTTP_X_FORWARDED_FOR"]
      logger.debug("Client IP: #{ip}")
  
      # Test UW-Madison 
      #ip = "128.104.198.84"
      
      # Test UIUC 
      #ip = "128.174.36.29"
      
      # Test Iowa
      #ip = "128.255.56.180"
  
      # Initialize ResolverRegistry
      client = ResolverRegistry::Client.new
      
      # @TODO: Can this be improved?
      #
      # Steps for ResolverRegistry results
      # 1) Look up *all* the resolvers held for a university 
      # * Some universities have more than one resolver (Iowa has 4!)
      # * Some resolvers look specific to ILL
      # * Some resolvers are for "Ask a Librarian" type services
      #
      # 2) If there are no results use the personalize.rb defaults
      #
      # 3) Loop through results
      #
      # 4) Choose best resolver option
      # * Best option (at least at UW, UIUC, Iowa) seems to be the resolver without specific metadata_formats
      begin
        institution = client.lookup_all(ip)
        
        # Test the ResolverRegistry results...
        # If the ResolverRegistry returns nil
        if institution.nil?
          # Use the default variables
        # Else loop and choose the "best option" 
        else
          institution.each do |i|
            if i.resolver.metadata_formats.empty?
              base_url = i.resolver.base_url
              link_text = i.resolver.link_text
              session[:openurl_link_text] = link_text
              session[:openurl_base_url] = base_url
            end
          end
        end
      rescue
        #If errors, do nothing - just use the defaults from personalize.rb
      end #end begin
      
      # whether we got results or not, flag that we already tried using OpenURL ResolverRegistry
      session[:openurl_info] = true
    end #end if session[:openurl_info]
=end
    return link_text, base_url, suffix
  end

  #mark stylesheets for inclusion in layout via yield :stylesheets
  #prevent including the same one more than once - note we could do
  #this more efficiently if need be
  def include_stylesheets(*paths)
    paths.each do |path|
      new_link = stylesheet_link_tag(path)
      unless content_for(:stylesheets).include?(new_link)
        content_for(:stylesheets, new_link + "\n")
      end
    end
  end
  alias include_stylesheet include_stylesheets

  def include_javascripts(*paths)
    paths.each do |path|
      new_link = javascript_include_tag(path)
      unless content_for(:javascripts).include?(new_link)
        content_for(:javascripts, new_link + "\n")
      end
    end
  end
  alias include_javascript include_javascripts

  #make a hidden div with the given id containing the given data, converted to json and html
  #encoded. We have a corresponding javascript function to take this back apart.
  def js_data_div(id, data)
    content_tag(:div, h(data.to_json), :id => id, :class => 'hidden')
  end
  
end
