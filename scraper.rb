require 'nokogiri'
require 'open-uri'
require 'sqlite3'
require 'logger'
require 'date'
require 'cgi'

# Set up a logger to log the scraped data
logger = Logger.new(STDOUT)

# Define the URL of the page
url = 'https://www.westcoast.tas.gov.au/planning-and-development/planning/advertised-development-applications/'

# Step 1: Fetch the page content
begin
  logger.info("Fetching page content from: #{url}")
  page_html = open(url).read
  logger.info("Successfully fetched page content.")
rescue => e
  logger.error("Failed to fetch page content: #{e}")
  exit
end

# Step 2: Parse the page content using Nokogiri
doc = Nokogiri::HTML(page_html)

# Step 3: Initialize the SQLite database
db = SQLite3::Database.new "data.sqlite"

# Create table
db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS west_coast (
    id INTEGER PRIMARY KEY,
    description TEXT,
    date_scraped TEXT,
    date_received TEXT,
    on_notice_to TEXT,
    address TEXT,
    council_reference TEXT,
    applicant TEXT,
    owner TEXT,
    stage_description TEXT,
    stage_status TEXT,
    document_description TEXT,
    title_reference TEXT
  );
SQL

# Define variables for storing extracted data for each entry
address = ''  
description = ''
on_notice_to = ''
title_reference = ''
date_received = ''
council_reference = ''
applicant = ''
owner = ''
stage_description = ''
stage_status = ''
document_description = ''
date_scraped = Date.today.to_s


# Loop through all the card listing items on the main page
doc.css('.card-listing__item').each_with_index do |item, index|
  # Extract the council reference (from the card-title)
  council_reference = item.at_css('.card-listing__title') ? item.at_css('.card-listing__title').text.strip : 'Council Reference not found'

  # Extract the address (from the card-content)
  address = item.at_css('.card-listing__content p') ? item.at_css('.card-listing__content p').text.strip : 'Address not found'

  # Extract the URL for the individual application
  application_url = item.at_css('.card-listing__link')['href'] if item.at_css('.card-listing__link')

  # Step 2.5: Visit the application URL for detailed information
  begin
    logger.info("Fetching detailed application from: #{application_url}")
    detail_page_html = open(application_url).read
    detail_doc = Nokogiri::HTML(detail_page_html)

    # Extract the description, address, and date received from the detailed page
    description = detail_doc.at_css('p:contains("Proposal:")') ? detail_doc.at_css('p:contains("Proposal:")').text.sub('Proposal: ', '').strip : 'Description not found'
    address = detail_doc.at_css('p:contains("Address:")') ? detail_doc.at_css('p:contains("Address:")').text.sub('Address: ', '').strip : 'Address not found'
    date_received = detail_doc.at_css('p:contains("Dated:")') ? detail_doc.at_css('p:contains("Dated:")').text.sub('Dated: ', '').strip : 'Date not found'

    # Extract supporting document link (if it exists)
    supporting_documents_link = detail_doc.at_css('a:contains("SUPPORTING DOCUMENTS")') ? detail_doc.at_css('a:contains("SUPPORTING DOCUMENTS")')['href'] : 'Supporting documents not found'

  rescue => e
    logger.error("Failed to fetch detailed application: #{e}")
    description = 'Description not found'
    address = 'Address not found'
    date_received = 'Date not found'
    supporting_documents_link = 'Supporting documents not found'
  end

  # Log the extracted data
  logger.info("Council Reference: #{council_reference}")
  logger.info("Address: #{address}")
  logger.info("Description: #{description}")
  logger.info("Date Received: #{date_received}")
  logger.info("Supporting Documents Link: #{supporting_documents_link}")
  logger.info("-----------------------------------")

  # Step 5: Ensure the entry does not already exist before inserting
  existing_entry = db.execute("SELECT * FROM west_coast WHERE council_reference = ?", council_reference)

  if existing_entry.empty?  # Only insert if the entry doesn't already exist
    # Save data to the database
    db.execute("INSERT INTO west_coast 
      (council_reference, address, description, date_received, on_notice_to, supporting_documents_link, date_scraped) 
      VALUES (?, ?, ?, ?, ?, ?, ?)",
      [council_reference, address, description, date_received, on_notice_to, supporting_documents_link, date_scraped])

    logger.info("Data for #{council_reference} saved to database.")
  else
    logger.info("Duplicate entry for document #{council_reference} found. Skipping insertion.")
  end
end

# Finish
logger.info("Data has been successfully inserted into the database.")
