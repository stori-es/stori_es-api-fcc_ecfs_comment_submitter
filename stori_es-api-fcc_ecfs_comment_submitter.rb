require 'rubygems'
require 'bundler/setup'

require 'uri'
require 'rest-client'
require 'json'
require 'mechanize'

DEBUG = true
PROCESSED_TAG = 'filed with fcc'
INVALID_TAG = 'invalid fcc comment'
VALIDATION_ERROR_TAG = 'fcc validation error'
CONFIRMATION_ERROR_TAG = 'fcc confirmation error'
REGION_TO_FCC_ECFS_STATE_ID = {
  'AK' => 1,
  'AL' => 2,
  'AR' => 3,
  'AZ' => 4,
  'CA' => 5,
  'CO' => 6,
  'CT' => 7,
  'DC' => 8,
  'DE' => 9,
  'FL' => 10,
  'GA' => 11,
  'GU' => 12,
  'HI' => 13,
  'IA' => 14,
  'ID' => 15,
  'IL' => 16,
  'IN' => 17,
  'KS' => 18,
  'KY' => 19,
  'LA' => 20,
  'MA' => 21,
  'MD' => 22,
  'ME' => 24,
  'MI' => 25,
  'MN' => 26,
  'MO' => 27,
  'MS' => 28,
  'MT' => 29,
  'NC' => 30,
  'ND' => 31,
  'NE' => 32,
  'NH' => 33,
  'NJ' => 34,
  'NM' => 35,
  'NV' => 36,
  'NY' => 37,
  'OH' => 38,
  'OK' => 39,
  'OR' => 40,
  'PA' => 41,
  'PR' => 42,
  'RI' => 43,
  'SC' => 44,
  'SD' => 45,
  'TN' => 46,
  'TX' => 47,
  'UT' => 48,
  'VA' => 49,
  'VI' => 51,
  'VT' => 52,
  'WA' => 53,
  'WI' => 54,
  'WV' => 55,
  'WY' => 56,
  'AS' => 57,
  'FM' => 58,
  'MH' => 59,
  'MP' => 60,
  'PW' => 61
}

# Ensure we have credentials for the target domain
env = ARGV[0].nil? ? 'y' : ARGV[0]
puts "Target environment: #{env}" if DEBUG

target = {
  'y' => {
    protocol: 'https',
    domain: 'y.stori.es', # stori.es domain
    api_key: '?',         # stori.es API Key
    collection: '?',      # stori.es Collection ID (e.g.: 123456)
    fcc_proceeding: '?'   # Target FCC proceeding ID (e.g.: 02-278)
  },
  'z' => {
    protocol: 'https',
    domain: 'stori.es',   # stori.es domain
    api_key: '?',         # stori.es API Key
    collection: '?',      # stori.es Collection ID (e.g.: 123456)
    fcc_proceeding: '?'   # Target FCC proceeding ID (e.g.: 02-278)
  }
}

target_endpoint = target[env][:protocol] + '://' +
    target[env][:domain] + '/api'

get_headers = {
  :Authorization => 'BASIC ' + target[env][:api_key],
  :accept => :json,
  'Cache-Control' => 'no-cache'
}

post_headers = {
  :Authorization => 'BASIC ' + target[env][:api_key],
  :content_type => 'application/json',
  'Cache-Control' => 'no-cache'
}


# Retrieve the target Collection
response = RestClient.get(target_endpoint + '/collections/' + target[env][:collection], get_headers)
collection = JSON.parse(response)['collections'][0]

if( (response.code == 200) && !collection.nil? )
  puts "Collection found: #{collection['title']}" if DEBUG
else
  puts "Collection not found: #{target[env][:collection]}" if DEBUG
  exit
end

# Iterate through the Collection's Stories
collection['links']['stories'].each do |story_link|
  puts "Story: #{story_link['href']}" if DEBUG

  begin
    tries ||= 3
    response = RestClient.get(story_link['href'], get_headers)
  rescue RestClient::ExceptionWithResponse => e
    puts "  ! Problem retrieving resource (HTTP #{e.response.code}: #{e.response.body})"
    if( (e.response.code == 504) && ((tries -= 1) > 0) )
      retry
    else
      puts '  - Resource not found' if DEBUG
      next
    end
  end

  # Parse the retrieved Story JSON
  story = JSON.parse(response)['stories'][0]
  puts "  + Story found: #{story['id']}" if DEBUG

  ## Skip if the Story has already been processed as indicated by Tag
  if( !story['tags'].index(PROCESSED_TAG).nil? )
    puts '  - Skipping, already filed with FCC' if DEBUG

    ### Remove Story from working Collection to speed subsequent load times
    # story_post = {
    #   'default_content_id': story['links']['default_content']['href'].match(/\/(\d+)$/)[1],
    #   'collection_ids': 'TBD',
    #   'tags': story['tags']
    # }
    # response = RestClient.put(target_endpoint + '/stories/' + story['id'].to_s, story_post.to_json, post_headers)
    # story = JSON.parse(response)['stories'][0]
    # puts "    + Story removed from working Collection" if DEBUG

    next
  elsif( !story['tags'].index(INVALID_TAG).nil? )
    puts '  - Skipping, invalid FCC comment' if DEBUG
    next
  elsif( !story['tags'].index(CONFIRMATION_ERROR_TAG).nil? )
    puts '  - Skipping, unconfirmed FCC comment' if DEBUG
    next
  end

  # Retrieve the Response Document
  response_link = story['links']['responses'][0]
  puts "  * Response Document: #{response_link['href']}" if DEBUG
  begin
    tries ||= 3
    response = RestClient.get(response_link['href'], get_headers)
  rescue RestClient::ExceptionWithResponse => e
    puts "    ! Problem retrieving resource (HTTP #{e.response.code}: #{e.response.body})"
    if( (e.response.code == 504) && ((tries -= 1) > 0) )
      retry
    else
      puts '    - Resource not found' if DEBUG
      next
    end
  end

  # Parse the retrieved Response Document JSON
  response_document = JSON.parse(response)['documents'][0]
  puts "    + Response Document found: #{response_document['id']}" if DEBUG

  # Pull the required Story values from the Response Document's Blocks
  story_values = {}
  response_document['blocks'].each do |block|
    case block['block_type']
      when 'FirstNameQuestionBlock'
        story_values[:first_name] = block['value'].strip
      when 'LastNameQuestionBlock'
        story_values[:last_name] = block['value'].strip
      when 'StreetAddressQuestionBlock'
        story_values[:street_address] = block['value'].strip
      when 'CityQuestionBlock'
        story_values[:city] = block['value'].strip
      when 'StateQuestionBlock'
        story_values[:state_abbreviation] = block['value'].strip
      when 'ZipCodeQuestionBlock'
        story_values[:zipcode] = block['value'].strip
    end
  end

  # Retrieve the default Content Document
  content_link = story['links']['default_content']
  puts "  * Content Document: #{content_link['href']}" if DEBUG
  begin
    tries ||= 3
    response = RestClient.get(content_link['href'], get_headers)
  rescue RestClient::ExceptionWithResponse => e
    puts "    ! Problem retrieving resource (HTTP #{e.response.code}: #{e.response.body})"
    if( (e.response.code == 504) && ((tries -= 1) > 0) )
      retry
    else
      puts '    - Resource not found' if DEBUG
      next
    end
  end

  # Parse the retrieved Content Document JSON
  content_document = JSON.parse(response)['documents'][0]
  puts "    + Content Document found: #{content_document['id']}" if DEBUG

  # Pull the required values from the Content Document's Blocks
  content_document['blocks'].each do |block|
    case block['block_type']
      when 'TextContentBlock'
        story_values[:content] = block['value']
    end
  end

  # Test to ensure Content Document contains at least five words (FCC requirement)
  if( story_values[:content].split.size <= 5 )
    puts '  * Content too short for FCC (minimum 5 words)...' if DEBUG
    story['tags'] << INVALID_TAG
    story_post = {
      'default_content_id': story['links']['default_content']['href'].match(/\/(\d+)$/)[1],
      'tags': story['tags']
    }
    response = RestClient.put(target_endpoint + '/stories/' + story['id'].to_s, story_post.to_json, post_headers)
    story = JSON.parse(response)['stories'][0]
    puts "    + Story tagged: '#{INVALID_TAG}'" if DEBUG
    next
  end

  # Prepare the comment data
  puts '  * Preparing FCC Comment...' if DEBUG
  comment = {}
  comment[:procName] = target[env][:fcc_proceeding]
  puts "    + FCC Proceeding: #{comment[:procName]}" if DEBUG

  comment[:applicant] = story_values[:first_name] + ' ' + story_values[:last_name]
  puts "    + Name of Filer: #{comment[:applicant]}" if DEBUG

  puts "    - Email Address: (not relaying)" if DEBUG

  comment['address.line1'] = story_values[:street_address]
  puts "    + Address Line 1: #{comment['address.line1']}" if DEBUG

  comment['address.city'] = story_values[:city]
  puts "    + City: #{comment['address.city']}" if DEBUG

  comment['address.state.id'] = REGION_TO_FCC_ECFS_STATE_ID[story_values[:state_abbreviation]]
  puts "    + State: #{comment['address.state.id']} (#{story_values[:state_abbreviation]})" if DEBUG

  if( story_values[:zipcode].size == 10 )
    comment['address.zip'] = story_values[:zipcode].slice(0, 5)
    comment['address.plusFour'] = story_values[:zipcode].slice(6, 4)
  else
    comment['address.zip'] = story_values[:zipcode].slice(0, 5)
    comment['address.plusFour'] = ''
  end
  puts "    + Zip: #{comment['address.zip']}" if DEBUG
  puts "    + +4: #{comment['address.plusFour']}" if DEBUG && !comment['address.plusFour'].empty?

  comment[:briefComment] = story_values[:content]
  puts "    + Comments: #{comment[:briefComment]}" if DEBUG

  ## Prepare the FCC's ECFS express filing interface
  agent = Mechanize.new
  ecfs_express_url = 'http://apps.fcc.gov/ecfs/upload/begin?procName=' + target[env][:fcc_proceeding] + '&filedFrom=X'
  puts "  * Preparing FCC express interface: [ #{ecfs_express_url} ]" if DEBUG
  ecfs_express_page = agent.get(ecfs_express_url)
  ecfs_express_form = ecfs_express_page.form_with(id: 'process')
  ecfs_express_form.set_fields(comment)

  ## Submit the Story/comment to the FCC's ECFS
  puts "    + Submitting..." if DEBUG
  ecfs_review_page = ecfs_express_form.submit(ecfs_express_form.button_with(name: 'action:process'))

  ## Check to see if we encountered a validation error
  unless( ecfs_review_page.form_with(id: 'process').nil? )
    puts "      - Validation error..." if DEBUG

    ## Document validation error as a Tag on the Story
    story['tags'] << VALIDATION_ERROR_TAG
    story_post = {
      'default_content_id': story['links']['default_content']['href'].match(/\/(\d+)$/)[1],
      'tags': story['tags']
    }
    response = RestClient.put(target_endpoint + '/stories/' + story['id'].to_s, story_post.to_json, post_headers)
    story = JSON.parse(response)['stories'][0]
    puts "    + Story tagged: '#{VALIDATION_ERROR_TAG}'" if DEBUG
    next
  end

  ## Confirm the upload
  ecfs_review_link = ecfs_review_page.link_with(href: /ecfs\/upload\/confirm/)
  puts "  * Review link [ #{ecfs_review_link.href.strip!} ]" if DEBUG
  puts "    + Clicking..." if DEBUG
  ecfs_confirmation_page = ecfs_review_link.click
  ecfs_confirmation_link = ecfs_confirmation_page.link_with(href: /ecfs\/comment\/confirm\?/)

  ## Test to ensure we were successful (repeated unidentified failures here)
  if( ecfs_confirmation_link.nil? )
    puts "  - Unable to identify Confirmation Status Link" if DEBUG
    story['tags'] << CONFIRMATION_ERROR_TAG
    story_post = {
      'default_content_id': story['links']['default_content']['href'].match(/\/(\d+)$/)[1],
      'tags': story['tags']
    }
    response = RestClient.put(target_endpoint + '/stories/' + story['id'].to_s, story_post.to_json, post_headers)
    story = JSON.parse(response)['stories'][0]
    puts "    + Story tagged: '#{CONFIRMATION_ERROR_TAG}'" if DEBUG
    next
  end

  ## Retrieve the confirmation number for the consumer comment
  ecfs_confirmation_number = ecfs_confirmation_link.href.match(/=(\d+)$/)[1]
  puts "  * Confirmation Status link [ #{ecfs_confirmation_link} ]" if DEBUG
  puts "    + Confirmation number: #{ecfs_confirmation_number}" if DEBUG

  ## Document the confirmation URL as an Attachment on the Story
  puts "  * Updating Story..." if DEBUG
  payload = {
    'document_type': 'AttachmentDocument',
    'entity_id': story['id'],
    'title': "FCC ECFS Confirmation Status (Proceeding #{target[env][:fcc_proceeding]})",
    'source': { 'href': ecfs_confirmation_link.href }
  }

  response = RestClient.post(target_endpoint + '/documents', payload.to_json, post_headers)
  attachment_document = JSON.parse(response)['documents'][0]
  puts "    + Attachment Document created: #{attachment_document['id']}" if DEBUG

  ## Document processing as a Tag on the Story
  ## TODO: and remove the Story from the working Collection
  story['tags'] << PROCESSED_TAG
  story_post = {
    'default_content_id': story['links']['default_content']['href'].match(/\/(\d+)$/)[1],
    'tags': story['tags']
  }
  response = RestClient.put(target_endpoint + '/stories/' + story['id'].to_s, story_post.to_json, post_headers)
  story = JSON.parse(response)['stories'][0]
  puts "    + Story tagged: '#{PROCESSED_TAG}'" if DEBUG
end
