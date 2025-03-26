# Setting Up AWS S3 for ActiveStorage

This guide provides instructions for configuring AWS S3 to work with ActiveStorage in this Rails application.

## Prerequisites

- AWS account
- IAM user with appropriate permissions
- S3 bucket created for the application

## IAM User Setup

1. Create an IAM user with programmatic access:
   - Go to IAM in AWS Console
   - Create a new user with programmatic access
   - Attach AmazonS3FullAccess policy or use a more restrictive custom policy

2. Custom policy for minimal permissions:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "s3:PutObject",
           "s3:GetObject",
           "s3:DeleteObject",
           "s3:ListBucket"
         ],
         "Resource": [
           "arn:aws:s3:::your-bucket-name",
           "arn:aws:s3:::your-bucket-name/*"
         ]
       }
     ]
   }
   ```

3. Store the access key and secret key securely.

## S3 Bucket Configuration

1. Create a new S3 bucket:
   - Go to S3 in AWS Console
   - Create a new bucket with a unique name
   - Select the region (typically use the same region as your application)
   - Configure bucket settings (typically block all public access)

2. Bucket policy (if needed):
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "AWS": "arn:aws:iam::YOUR_ACCOUNT_ID:user/YOUR_IAM_USER"
         },
         "Action": [
           "s3:PutObject",
           "s3:GetObject",
           "s3:DeleteObject",
           "s3:ListBucket"
         ],
         "Resource": [
           "arn:aws:s3:::your-bucket-name",
           "arn:aws:s3:::your-bucket-name/*"
         ]
       }
     ]
   }
   ```

3. CORS configuration for direct uploads:
   ```json
   [
     {
       "AllowedHeaders": [
         "*"
       ],
       "AllowedMethods": [
         "GET",
         "POST",
         "PUT",
         "DELETE"
       ],
       "AllowedOrigins": [
         "https://your-app-domain.com",
         "http://localhost:3000"
       ],
       "ExposeHeaders": [
         "ETag"
       ],
       "MaxAgeSeconds": 3000
     }
   ]
   ```

## Rails Configuration

1. Update `config/storage.yml`:
   ```yaml
   amazon:
     service: S3
     access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] || Rails.application.credentials.dig(:aws, :access_key_id) %>
     secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] || Rails.application.credentials.dig(:aws, :secret_access_key) %>
     region: <%= ENV['AWS_REGION'] || Rails.application.credentials.dig(:aws, :region) || 'us-east-1' %>
     bucket: <%= ENV['AWS_BUCKET'] || Rails.application.credentials.dig(:aws, :bucket) %>
     # For buckets with Block Public Access
     # Don't set ACLs or public flags - access will be managed by bucket policy
     force_path_style: true
   ```

2. Update `config/environments/production.rb`:
   ```ruby
   # Store files on Amazon S3
   config.active_storage.service = :amazon
   ```

3. Add credentials (either in Rails credentials or environment variables):
   ```bash
   # Using Rails credentials
   rails credentials:edit
   
   # Add the following:
   aws:
     access_key_id: YOUR_ACCESS_KEY
     secret_access_key: YOUR_SECRET_KEY
     region: us-east-1
     bucket: your-bucket-name
   
   # Or using environment variables (recommended for production)
   export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY
   export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY
   export AWS_REGION=us-east-1
   export AWS_BUCKET=your-bucket-name
   ```

## Testing the Configuration

You can test the S3 configuration with the provided Rake task:

```bash
bundle exec rake test_s3:connection
```

The task will:
1. Connect to S3 using your credentials
2. Upload a test file to your bucket
3. Verify the file exists
4. Delete the test file
5. Report the results

## Troubleshooting

### Common Issues

1. **Access Denied Errors**:
   - Check IAM user permissions
   - Verify bucket policy
   - Ensure environment variables or credentials are correct

2. **CORS Issues** (during direct uploads):
   - Verify CORS configuration in S3 bucket settings
   - Make sure the AllowedOrigins includes your application domain

3. **Invalid Endpoint**:
   - Check the region configuration
   - Ensure the bucket name is correct

4. **File Not Found**:
   - Check if the file was uploaded to the correct bucket
   - Verify the path used to access the file

### Testing S3 Connection

From the Rails console:

```ruby
require 'aws-sdk-s3'

s3 = Aws::S3::Client.new(
  access_key_id: ENV['AWS_ACCESS_KEY_ID'] || Rails.application.credentials.dig(:aws, :access_key_id),
  secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'] || Rails.application.credentials.dig(:aws, :secret_access_key),
  region: ENV['AWS_REGION'] || Rails.application.credentials.dig(:aws, :region) || 'us-east-1'
)

bucket = ENV['AWS_BUCKET'] || Rails.application.credentials.dig(:aws, :bucket)

# List buckets to verify connection
s3.list_buckets.buckets.map(&:name)

# Test putting an object
s3.put_object(
  bucket: bucket,
  key: 'test.txt',
  body: 'This is a test file'
)

# Test getting an object
s3.get_object(
  bucket: bucket,
  key: 'test.txt'
).body.read

# Test deleting an object
s3.delete_object(
  bucket: bucket,
  key: 'test.txt'
)
```

## Security Considerations

1. **IAM Best Practices**:
   - Use least privilege principle for IAM permissions
   - Rotate access keys regularly
   - Consider using IAM roles instead of user keys for EC2/ECS deployments

2. **Bucket Security**:
   - Enable versioning for important data
   - Set up lifecycle policies for cost management
   - Consider enabling server-side encryption
   - Set appropriate bucket policies

3. **Application Security**:
   - Don't commit AWS credentials to source control
   - Use signed URLs for public access to private resources
   - Implement proper validation for file uploads

## Additional Resources

- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/index.html)
- [ActiveStorage S3 Guide](https://edgeguides.rubyonrails.org/active_storage_overview.html#amazon-s3-service)
- [AWS SDK for Ruby](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/)