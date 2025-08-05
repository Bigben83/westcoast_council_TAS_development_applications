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


doc.css('.uael-post__inner-wrap').each do |item|
  # Extract Council Reference & Address from Title
  title_text = item.at_css('.uael-post__title a')&.text&.strip || ''
  if title_text =~ /(DA\d{4}\/\d{2}):\s*(.+)/
    council_reference = $1
    address = $2
  else
    council_reference = 'Council Reference not found'
    address = 'Address not found'
  end

  # Extract Description and On Notice To date from excerpt
  excerpt_text = item.at_css('.uael-post__excerpt')&.text&.strip || ''
  description = excerpt_text.split('Representations must').first&.strip || 'Description not found'
  on_notice_to = excerpt_text[/Representations must be made by (.+?)\./, 1]&.strip || 'On Notice To not found'

  # Extract Detail URL
  detail_url = item.at_css('.uael-post__title a')&.[]('href') || ''

  # Log extracted data
  logger.info("Council Reference: #{council_reference}")
  logger.info("Address: #{address}")
  logger.info("Description: #{description}")
  logger.info("On Notice To: #{on_notice_to}")
  logger.info("Detail URL: #{detail_url}")
  logger.info("-----------------------------------")

  # Check for existing entry
  existing_entry = db.execute("SELECT * FROM west_coast WHERE council_reference = ?", council_reference)
  if existing_entry.empty?
    db.execute("INSERT INTO west_coast (council_reference, address, description, on_notice_to, document_description, date_scraped)  VALUES (?, ?, ?, ?, ?, ?)",
      [council_reference, address, description, on_notice_to, detail_url, date_scraped])
    logger.info("Data for #{council_reference} saved to database.")
  else
    logger.info("Duplicate entry for document #{council_reference} found. Skipping insertion.")
  end
end


# Finish
logger.info("Data has been successfully inserted into the database.")
