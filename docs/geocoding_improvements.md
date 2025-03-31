# Geocoding Improvements

## Background

In the previous implementation, the geocoding system would combine both `location` and `mailing_address` fields into a single string for geocoding:

```ruby
def full_address
  [mailing_address, location].reject(&:blank?).join(', ')
end
```

This approach caused issues when a profile had both fields populated with locations in different countries. For example, profile #63 had:
- `location`: "Dublin, Ireland"
- `mailing_address`: "303 W Madison, STE 950, Chicago, IL 60606"

When combined into "303 W Madison, STE 950, Chicago, IL 60606, Dublin, Ireland", the geocoding service couldn't find a match because this isn't a valid address.

## Changes Made

1. **Modified `full_address` method** to prioritize the `location` field:
   ```ruby
   def full_address
     # If location is present, use it exclusively for mapping purposes
     return location if location.present?
     
     # Otherwise fall back to mailing address
     mailing_address
   end
   ```
   
   This ensures that we use the most appropriate field for map placement.

2. **Enhanced `GeocodeProfileJob`** with more robust logic:
   - Better logging of which address is being used
   - Fallback to mailing address if location field geocoding fails
   - Improved error handling and reporting

## Benefits

1. **More accurate map placement** - Profiles are now more likely to appear on the map at their actual location rather than a mixed address that doesn't exist.

2. **Better fallback behavior** - If the primary address can't be geocoded, the system will try the secondary address.

3. **Improved transparency** - Detailed logging makes it clear which address was used for geocoding.

## Usage Notes

- The system will now prioritize the `location` field for geocoding.
- If a profile has no location but has a mailing address, the mailing address will be used.
- For profiles with both fields, if location can't be geocoded, the system will try the mailing address as a fallback.

## Example

For profile #63 (Adam Sher):
- Previously: Would try to geocode "303 W Madison, STE 950, Chicago, IL 60606, Dublin, Ireland" (fails)
- Now: Will try to geocode "Dublin, Ireland" (succeeds)