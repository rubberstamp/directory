# Guest List Import

This document outlines the steps to update the database to support the guest list data and import it from the CSV file.

## Database Migration

First, run the migration to add the necessary fields to the profiles table:

```bash
rails db:migrate
```

This will add the following fields to the profiles table:
- company
- website
- mailing_address
- facebook_url
- twitter_url
- instagram_url
- tiktok_url
- testimonial
- headshot_url
- interested_in_procurement
- submission_date

## Data Import

To import the data from the CSV file, run the following rake task:

```bash
rails guest_list:import
```

This will:
1. Read the CSV file from `data/guest_list.csv`
2. Create a new profile for each guest or update an existing one if the name matches
3. Parse and clean the data, including social media URLs
4. Set default values for missing fields
5. Log the results of the import

## Data Validation

The Profile model includes validations for all URL fields to ensure they are properly formatted. If any validation errors occur during import, they will be displayed in the console.

## Notes

- Email addresses are extracted from the "Physical Mailing Address" column if they contain an @ symbol, otherwise a default email is generated
- Social media URLs are cleaned to add "https://" if missing and to handle common cases like "n/a", "N/A", etc.
- The submission date is parsed from the "Timestamp" column