require 'nokogiri'
require 'open-uri'
require 'sqlite3'
require 'logger'
require 'date'
require 'cgi'

# Set up a logger to log the scraped data
logger = Logger.new(STDOUT)

# Define the URL of the page
url = 'https://www.westcoast.tas.gov.au/public-and-environmental-health/planning/planning-applications'

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
  CREATE TABLE IF NOT EXISTS westcoast (
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


# Loop through all the card listing items
doc.css('.card-listing__item').each_with_index do |item, index|
  # Extract the council reference (from the card-title)
  council_reference = item.at_css('.card-listing__title') ? item.at_css('.card-listing__title').text.strip : 'Council Reference not found'

  # Extract the address (from the card-content)
  address = item.at_css('.card-listing__content p') ? item.at_css('.card-listing__content p').text.strip : 'Address not found'

  # Extract the URL (from the anchor tag)
  pdf_link = item.at_css('.card-listing__link')['href'] if item.at_css('.card-listing__link')

  # Placeholder for date information (assuming no date is provided on this page)
  date_received = ''
  on_notice_to = ''
  
  # Log the extracted data for debugging purposes
    logger.info("Council Reference: #{council_reference}")
    logger.info("Address: #{address}")
    logger.info("Description: #{description}")
    logger.info("Date Received: #{date_received}")
    logger.info("On Notice To: #{on_notice_to}")
    logger.info("PDF Link: #{document_description}")
    logger.info("-----------------------------------")
  
  # Step 6: Ensure the entry does not already exist before inserting
  existing_entry = db.execute("SELECT * FROM westcoast WHERE council_reference = ?", council_reference )

  if existing_entry.empty? # Only insert if the entry doesn't already exist
  # Step 5: Insert the data into the database
  db.execute("INSERT INTO westcoast (address, council_reference, on_notice_to, description, document_description, date_scraped)
              VALUES (?, ?, ?, ?, ?, ?)", [address, council_reference, on_notice_to, description, document_description, date_scraped])

  logger.info("Data for #{council_reference} saved to database.")
    else
      logger.info("Duplicate entry for application #{council_reference} found. Skipping insertion.")
    end

end
